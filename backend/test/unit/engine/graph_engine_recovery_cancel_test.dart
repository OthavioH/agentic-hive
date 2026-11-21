import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';
import 'support/fake_ports.dart';

void main() {
  late EngineHarness h;

  setUp(() => h = EngineHarness());

  group('GraphEngine interrupted run recovery', () {
    Workflow chain() => buildWorkflow(
      nodeIds: ['a', 'b', 'c'],
      edges: [
        edge('a', NodeOutput.onSuccess, 'b'),
        edge('b', NodeOutput.onSuccess, 'c'),
      ],
    );

    /// A run that crashed while `b` was executing: `a` is done, `b` was
    /// pending in the last checkpoint and its pre-node snapshot exists.
    Future<void> crashedDuringB() async {
      await h.createRun(chain());
      await h.snapshots.captureSnapshot(
        runId: runId,
        workspaceDir: '/workspace',
        nodeId: 'a',
      );
      await h.checkpoints.append(
        id: 'cp-seed',
        runId: runId,
        pendingNodeIds: ['b'],
        attemptsByEdge: {'a-onSuccess-b': 2},
        circuitBreakerCount: 2,
        nodeOutputs: {
          'a': {
            'outputLabel': NodeOutput.onSuccess,
            'data': <String, Object?>{},
            'artifacts': <String>[],
          },
        },
        createdAt: h.tick(),
        completedNodeId: 'a',
      );
      await h.snapshots.captureSnapshot(
        runId: runId,
        workspaceDir: '/workspace',
        nodeId: 'b',
      );
      await h.recovery.recoverOrphanedRuns();
    }

    test('rolls back, resets the breaker and keeps attemptsByEdge', () async {
      await crashedDuringB();
      expect(h.run.status, RunStatus.interrupted);
      final snapshotBeforeB = h.snapshots.snapshots.last;
      // With the old count of 2 a single infrastructure failure would trip
      // the breaker; the reset to 0 lets it recover.
      h.script.on('b', [infraFailure(), outcome(NodeOutput.onSuccess)]);

      final result = await h.engine.resume(runId);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.snapshots.restored, [snapshotBeforeB.id]);
      expect(h.script.runsOf('a'), 0);
      expect(h.script.startOrder, ['b', 'b', 'c']);
      expect(h.checkpoints.checkpoints.last.attemptsByEdge, {
        'a-onSuccess-b': 2,
      });
      final resumed = h.events.ofType(runId, RunEventType.runResumed).single;
      expect(resumed.payload['from'], 'interrupted');
    });

    test('does not need any input to resume', () async {
      await crashedDuringB();

      final result = await h.engine.resume(runId);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
    });

    test(
      'skips the rollback when the interrupted node never snapshotted',
      () async {
        await h.createRun(chain());
        await h.checkpoints.append(
          id: 'cp-seed',
          runId: runId,
          pendingNodeIds: ['a'],
          attemptsByEdge: const {},
          circuitBreakerCount: 0,
          nodeOutputs: const {},
          createdAt: h.tick(),
        );
        await h.recovery.recoverOrphanedRuns();

        final result = await h.engine.resume(runId);

        expect(result.valueOrNull?.status, RunStatus.succeeded);
        expect(h.snapshots.restored, isEmpty);
        expect(h.script.startOrder, ['a', 'b', 'c']);
      },
    );

    test('ignores snapshots taken before the last checkpoint', () async {
      await crashedDuringB();
      // Only the snapshot of `a` (older than the checkpoint) matches `a`.
      final aSnapshot = h.snapshots.snapshots.first;
      expect(aSnapshot.nodeId, 'a');

      await h.engine.resume(runId);

      expect(h.snapshots.restored, isNot(contains(aSnapshot.id)));
    });

    test('stays interrupted when the rollback fails', () async {
      await crashedDuringB();
      h.snapshots.restoreFailure = const NodeExecutionFailure('git failed');

      final result = await h.engine.resume(runId);

      expect(result.isFailure, isTrue);
      expect(h.run.status, RunStatus.interrupted);
      expect(h.script.executions, isEmpty);
    });

    test('restarts from the entry node when no checkpoint exists', () async {
      await h.createRun(chain());
      await h.recovery.recoverOrphanedRuns();

      final result = await h.engine.resume(runId);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.startOrder, ['a', 'b', 'c']);
    });
  });

  group('GraphEngine cancellation', () {
    test(
      'a running run reports cancelled only after the kill is confirmed',
      () async {
        final exit = Completer<void>();
        final hung = Completer<void>();
        h.killer
          ..confirmation = exit.future
          ..onKill = ((runId, nodeId) => hung.complete());
        h.script.on('a', [
          (_) async {
            await hung.future;
            return const FailureResult(NodeExecutionFailure('killed'));
          },
        ]);
        await h.createRun(
          buildWorkflow(
            nodeIds: ['a', 'b'],
            edges: [edge('a', NodeOutput.onSuccess, 'b')],
          ),
        );

        final started = h.engine.start(runId);
        await h.settle();
        final cancelled = h.engine.cancel(runId);
        await h.settle();

        expect(h.killer.kills, [(runId, null)]);
        expect(h.run.status, RunStatus.running);
        expect(h.eventTypes, isNot(contains(RunEventType.runCancelled)));

        exit.complete();
        final result = await cancelled;

        expect(result.valueOrNull?.status, RunStatus.cancelled);
        expect((await started).valueOrNull?.status, RunStatus.cancelled);
        expect(h.run.status, RunStatus.cancelled);
        expect(h.eventTypes.last, RunEventType.runCancelled);
        expect(h.script.runsOf('b'), 0);
        expect(h.events.ofType(runId, RunEventType.nodeFailed), isEmpty);
      },
    );

    test('aborts every parallel branch', () async {
      final hung = Completer<void>();
      h.killer.onKill = (runId, nodeId) => hung.complete();
      for (final id in ['b', 'c']) {
        h.script.on(id, [outcomeAfter(hung.future, NodeOutput.onSuccess)]);
      }
      await h.createRun(
        buildWorkflow(
          nodeIds: ['a', 'b', 'c'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'b'),
            edge('a', NodeOutput.onSuccess, 'c'),
          ],
        ),
      );

      final started = h.engine.start(runId);
      await h.settle();
      await h.engine.cancel(runId);
      await started;

      expect(h.run.status, RunStatus.cancelled);
      expect(h.killer.kills, hasLength(1));
      expect(h.killer.confirmed, isTrue);
    });

    test(
      'stays running when the process tree exit cannot be confirmed',
      () async {
        final hung = Completer<void>();
        h.killer
          ..failure = const NodeExecutionFailure('still alive')
          ..onKill = ((runId, nodeId) => hung.complete());
        h.script.on('a', [outcomeAfter(hung.future, NodeOutput.onSuccess)]);
        await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));

        final started = h.engine.start(runId);
        await h.settle();
        final result = await h.engine.cancel(runId);
        await started;

        expect(result.failureOrNull, isA<ConflictFailure>());
        expect(h.run.status, RunStatus.running);
        expect(h.eventTypes, isNot(contains(RunEventType.runCancelled)));
        expect(h.engine.isExecuting(runId), isFalse);
      },
    );

    test('a paused run is cancelled immediately without killing', () async {
      await h.createRun(
        buildWorkflow(
          nodeIds: ['gate', 'next'],
          approvals: {'gate'},
          edges: [edge('gate', NodeOutput.approved, 'next')],
        ),
      );
      await h.engine.start(runId);
      expect(h.run.status, RunStatus.paused);

      final result = await h.engine.cancel(runId);

      expect(result.valueOrNull?.status, RunStatus.cancelled);
      expect(h.run.finishedAt, isNotNull);
      expect(h.killer.kills, isEmpty);
      expect(h.eventTypes.last, RunEventType.runCancelled);
    });

    test('a paused ask_human run releases its pending question', () async {
      h.script.on('ask', [
        (context) async {
          final reply = await h.gateway.requestHumanAnswer(
            runId: context.runId,
            nodeId: context.nodeId,
            attempt: context.attempt,
            question: 'Which one?',
          );
          return reply.map((a) => const NodeOutcome(outputLabel: 'onSuccess'));
        },
      ]);
      await h.createRun(buildWorkflow(nodeIds: ['ask'], edges: const []));
      await h.engine.start(runId);

      final result = await h.engine.cancel(runId);

      expect(result.valueOrNull?.status, RunStatus.cancelled);
      expect(h.gateway.allPending, isEmpty);
    });

    test('an interrupted run is cancelled immediately', () async {
      await h.createRun(
        buildWorkflow(nodeIds: ['a'], edges: const []),
        status: RunStatus.interrupted,
      );

      final result = await h.engine.cancel(runId);

      expect(result.valueOrNull?.status, RunStatus.cancelled);
      expect(h.killer.kills, isEmpty);
    });

    test('rejects cancelling a finished run', () async {
      await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));
      await h.engine.start(runId);

      final result = await h.engine.cancel(runId);

      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test(
      'rejects cancelling a running run this process does not drive',
      () async {
        await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));

        final result = await h.engine.cancel(runId);

        expect(result.failureOrNull, isA<ConflictFailure>());
        expect(h.run.status, RunStatus.running);
      },
    );

    test('returns NotFoundFailure for an unknown run', () async {
      final result = await h.engine.cancel('missing');

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('cancelling a paused run is not confused with a resume', () async {
      await h.createRun(
        buildWorkflow(nodeIds: ['gate'], approvals: {'gate'}, edges: const []),
      );
      await h.engine.start(runId);
      await h.engine.cancel(runId);

      final resume = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );

      expect(resume.failureOrNull, isA<ConflictFailure>());
    });
  });
}
