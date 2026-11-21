import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';
import 'support/fake_ports.dart';

void main() {
  Future<Result<Run>> startRun(EngineHarness h, Workflow workflow) async {
    await h.createRun(workflow);
    return await h.engine.start(runId);
  }

  group('GraphEngine parallel fan-out', () {
    test('runs edges sharing (source, output) concurrently', () async {
      final h = EngineHarness();
      final gate = Completer<void>();
      h.script
        ..on('b', [outcomeAfter(gate.future, NodeOutput.onSuccess)])
        ..on('c', [
          (context) async {
            gate.complete();
            return const Success(
              NodeOutcome(outputLabel: NodeOutput.onSuccess),
            );
          },
        ]);

      final result = await startRun(
        h,
        buildWorkflow(
          nodeIds: ['a', 'b', 'c'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'b'),
            edge('a', NodeOutput.onSuccess, 'c'),
          ],
        ),
      );

      // b only finishes after c started, so they overlapped.
      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.maxActive, 2);
    });

    test('never runs more than maxConcurrency nodes at once', () async {
      final h = EngineHarness(maxConcurrency: 2);
      for (final id in ['b', 'c', 'd', 'e']) {
        h.script.on(id, [
          (context) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return const Success(
              NodeOutcome(outputLabel: NodeOutput.onSuccess),
            );
          },
        ]);
      }

      final result = await startRun(
        h,
        buildWorkflow(
          nodeIds: ['a', 'b', 'c', 'd', 'e'],
          edges: [
            for (final id in ['b', 'c', 'd', 'e'])
              edge('a', NodeOutput.onSuccess, id),
          ],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.maxActive, 2);
      expect(h.script.startOrder.toSet(), {'a', 'b', 'c', 'd', 'e'});
    });

    test('serializes snapshots at the divergence point', () async {
      final h = EngineHarness();
      final capturedWhenStarted = <String, int>{};
      for (final id in ['b', 'c', 'd']) {
        h.script.on(id, [
          (context) async {
            capturedWhenStarted[id] = h.snapshots.captured.length;
            return const Success(
              NodeOutcome(outputLabel: NodeOutput.onSuccess),
            );
          },
        ]);
      }

      await startRun(
        h,
        buildWorkflow(
          nodeIds: ['a', 'b', 'c', 'd'],
          edges: [
            for (final id in ['b', 'c', 'd'])
              edge('a', NodeOutput.onSuccess, id),
          ],
        ),
      );

      expect(h.snapshots.maxInFlight, 1);
      expect(h.snapshots.captured, ['a', 'b', 'c', 'd']);
      // Every branch snapshot exists before any branch starts executing.
      expect(capturedWhenStarted.values, everyElement(4));
    });
  });

  group('GraphEngine fan-in', () {
    test('runs a join node once, after every branch finished', () async {
      final h = EngineHarness();
      final releaseC = Completer<void>();
      h.script.on('c', [outcomeAfter(releaseC.future, NodeOutput.onSuccess)]);
      h.script.on('b', [
        (context) async {
          // Let the join have its chance to (wrongly) start early.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          releaseC.complete();
          return const Success(NodeOutcome(outputLabel: NodeOutput.onSuccess));
        },
      ]);

      final result = await startRun(
        h,
        buildWorkflow(
          nodeIds: ['a', 'b', 'c', 'join'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'b'),
            edge('a', NodeOutput.onSuccess, 'c'),
            edge('b', NodeOutput.onSuccess, 'join'),
            edge('c', NodeOutput.onSuccess, 'join'),
          ],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.runsOf('join'), 1);
      expect(h.script.startOrder.last, 'join');
      final predecessors =
          h.script.executions.last.inputs['predecessors']!
              as Map<String, Object?>;
      expect(predecessors.keys, unorderedEquals(['b', 'c']));
    });

    test(
      'a conditional merge does not wait for the branch not taken',
      () async {
        final h = EngineHarness();

        final result = await startRun(
          h,
          buildWorkflow(
            nodeIds: ['a', 'yes', 'no', 'merge'],
            edges: [
              edge('a', NodeOutput.onSuccess, 'yes'),
              edge('a', NodeOutput.onFailure, 'no'),
              edge('yes', NodeOutput.onSuccess, 'merge'),
              edge('no', NodeOutput.onSuccess, 'merge'),
            ],
          ),
        );

        expect(result.valueOrNull?.status, RunStatus.succeeded);
        expect(h.script.startOrder, ['a', 'yes', 'merge']);
      },
    );

    test(
      'a join reached by a longer branch waits for the deeper node',
      () async {
        final h = EngineHarness();
        final order = <String>[];
        for (final id in ['b', 'c', 'd', 'join']) {
          h.script.on(id, [
            (context) async {
              order.add('start:$id');
              await Future<void>.delayed(const Duration(milliseconds: 3));
              order.add('end:$id');
              return const Success(
                NodeOutcome(outputLabel: NodeOutput.onSuccess),
              );
            },
          ]);
        }

        await startRun(
          h,
          buildWorkflow(
            nodeIds: ['a', 'b', 'c', 'd', 'join'],
            edges: [
              edge('a', NodeOutput.onSuccess, 'b'),
              edge('a', NodeOutput.onSuccess, 'c'),
              edge('c', NodeOutput.onSuccess, 'd'),
              edge('b', NodeOutput.onSuccess, 'join'),
              edge('d', NodeOutput.onSuccess, 'join'),
            ],
          ),
        );

        expect(h.script.runsOf('join'), 1);
        expect(
          order.indexOf('start:join'),
          greaterThan(order.indexOf('end:d')),
        );
        expect(
          order.indexOf('start:join'),
          greaterThan(order.indexOf('end:b')),
        );
      },
    );
  });

  group('GraphEngine fail-fast', () {
    test('an unhandled branch failure cancels active siblings', () async {
      final h = EngineHarness();
      final siblingGate = Completer<void>();
      h.killer.onKill = (runId, nodeId) => siblingGate.complete();
      h.script
        ..on('slow', [outcomeAfter(siblingGate.future, NodeOutput.onSuccess)])
        ..on('bad', [
          (context) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return const Success(
              NodeOutcome(outputLabel: NodeOutput.onFailure),
            );
          },
        ]);

      final result = await startRun(
        h,
        buildWorkflow(
          nodeIds: ['a', 'slow', 'bad', 'after'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'slow'),
            edge('a', NodeOutput.onSuccess, 'bad'),
            edge('slow', NodeOutput.onSuccess, 'after'),
          ],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.killer.kills, [(runId, null)]);
      expect(h.killer.confirmed, isTrue);
      expect(h.script.runsOf('after'), 0);
      expect(h.eventTypes.last, RunEventType.runFailed);
    });

    test('waits for process-tree exit confirmation before failing', () async {
      final h = EngineHarness();
      final siblingGate = Completer<void>();
      final confirmation = Completer<void>();
      h.killer
        ..onKill = ((runId, nodeId) => siblingGate.complete())
        ..confirmation = confirmation.future;
      h.script
        ..on('slow', [outcomeAfter(siblingGate.future, NodeOutput.onSuccess)])
        ..on('bad', [outcome(NodeOutput.onFailure)]);

      final run = startRun(
        h,
        buildWorkflow(
          nodeIds: ['a', 'slow', 'bad'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'slow'),
            edge('a', NodeOutput.onSuccess, 'bad'),
          ],
        ),
      );
      await h.settle();

      expect(h.killer.kills, isNotEmpty);
      expect(h.run.status, RunStatus.running);
      expect(h.eventTypes, isNot(contains(RunEventType.runFailed)));

      confirmation.complete();
      final result = await run;

      expect(result.valueOrNull?.status, RunStatus.failed);
    });

    test(
      'reports kill_unconfirmed when the siblings cannot be confirmed gone',
      () async {
        final h = EngineHarness();
        final siblingGate = Completer<void>();
        h.killer
          ..failure = const NodeExecutionFailure('still alive')
          ..onKill = ((runId, nodeId) => siblingGate.complete());
        h.script
          ..on('slow', [outcomeAfter(siblingGate.future, NodeOutput.onSuccess)])
          ..on('bad', [outcome(NodeOutput.onFailure)]);

        final result = await startRun(
          h,
          buildWorkflow(
            nodeIds: ['a', 'slow', 'bad'],
            edges: [
              edge('a', NodeOutput.onSuccess, 'slow'),
              edge('a', NodeOutput.onSuccess, 'bad'),
            ],
          ),
        );

        expect(result.valueOrNull?.status, RunStatus.failed);
        final failed = h.events.ofType(runId, RunEventType.runFailed).single;
        expect(failed.payload['kill_unconfirmed'], isTrue);
        expect(failed.payload['kill_error'], 'still alive');
        expect(h.run.errorMessage, contains('unconfirmed'));
      },
    );

    test('does not kill anything when no sibling is active', () async {
      final h = EngineHarness();
      h.script.on('a', [outcome(NodeOutput.onFailure)]);

      await startRun(h, buildWorkflow(nodeIds: ['a'], edges: const []));

      expect(h.killer.kills, isEmpty);
    });

    test('ignores the result of a cancelled sibling', () async {
      final h = EngineHarness();
      final siblingGate = Completer<void>();
      h.killer.onKill = (runId, nodeId) => siblingGate.complete();
      h.script
        ..on('slow', [
          (context) async {
            await siblingGate.future;
            return const FailureResult(NodeExecutionFailure('killed'));
          },
        ])
        ..on('bad', [outcome(NodeOutput.onFailure)]);

      await startRun(
        h,
        buildWorkflow(
          nodeIds: ['a', 'slow', 'bad'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'slow'),
            edge('a', NodeOutput.onSuccess, 'bad'),
          ],
        ),
      );

      expect(h.run.status, RunStatus.failed);
      expect(
        h.events.ofType(runId, RunEventType.nodeFailed),
        isEmpty,
        reason:
            'the killed sibling must not count as an infrastructure '
            'failure',
      );
    });
  });
}
