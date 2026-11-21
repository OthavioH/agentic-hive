import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
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

  group('GraphEngine interrupted rollback selection', () {
    Workflow fan() => buildWorkflow(
      nodeIds: ['a', 'b', 'c'],
      edges: [
        edge('a', NodeOutput.onSuccess, 'b'),
        edge('a', NodeOutput.onSuccess, 'c'),
      ],
    );

    Future<void> seedCheckpoint({
      required List<String> pending,
      required String completed,
    }) => h.checkpoints.append(
      id: 'cp-${h.checkpoints.checkpoints.length}',
      runId: runId,
      pendingNodeIds: pending,
      attemptsByEdge: const {},
      circuitBreakerCount: 0,
      nodeOutputs: const {},
      createdAt: h.tick(),
      completedNodeId: completed,
    );

    Future<Snapshot> snapshotOf(String nodeId) async {
      await h.snapshots.captureSnapshot(
        runId: runId,
        workspaceDir: '/workspace',
        nodeId: nodeId,
      );
      return h.snapshots.snapshots.last;
    }

    test('rolls back a node running at the last checkpoint', () async {
      await h.createRun(fan());
      // c started, then b (re-queued by a loop) completed: the checkpoint that
      // names b as completed is newer than c's snapshot, but b is itself
      // pending again, so no finished node's work is lost.
      final snapshotC = await snapshotOf('c');
      await seedCheckpoint(pending: ['b', 'c'], completed: 'b');
      await snapshotOf('b');
      await h.recovery.recoverOrphanedRuns();

      final result = await h.engine.resume(runId);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.snapshots.restored, [snapshotC.id]);
    });

    test('never restores a snapshot older than a completed node', () async {
      await h.createRun(fan());
      await snapshotOf('c');
      // b is not pending: it finished after c's snapshot, so restoring that
      // snapshot would erase b's work.
      await seedCheckpoint(pending: ['c'], completed: 'b');
      await h.recovery.recoverOrphanedRuns();

      final result = await h.engine.resume(runId);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.snapshots.restored, isEmpty);
      final skipped = h.events
          .ofType(runId, RunEventType.snapshotWarning)
          .where((e) => e.payload['reason'] == 'rollback_skipped');
      expect(skipped, hasLength(1));
    });
  });

  group('GraphEngine terminal status writes', () {
    test('a failed status write leaves no run.failed event behind', () async {
      h.runs.failingStatuses.add(RunStatus.failed);
      h.script.on('a', [outcome(NodeOutput.onFailure)]);
      await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));

      final result = await h.engine.start(runId);

      expect(result.failureOrNull, isA<PersistenceFailure>());
      expect(h.run.status, RunStatus.running);
      expect(h.eventTypes, isNot(contains(RunEventType.runFailed)));
    });

    test(
      'a failed status write leaves no run.cancelled event behind',
      () async {
        h.runs.failingStatuses.add(RunStatus.cancelled);
        await h.createRun(
          buildWorkflow(
            nodeIds: ['gate'],
            approvals: {'gate'},
            edges: const [],
          ),
        );
        await h.engine.start(runId);

        final result = await h.engine.cancel(runId);

        expect(result.failureOrNull, isA<PersistenceFailure>());
        expect(h.run.status, RunStatus.paused);
        expect(h.eventTypes, isNot(contains(RunEventType.runCancelled)));
      },
    );

    test('the status is written before the terminal event', () async {
      await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));
      RunStatus? statusWhenEventLogged;
      h.events.onAppend = (event) {
        if (event.type == RunEventType.runSucceeded) {
          statusWhenEventLogged = h.run.status;
        }
      };

      await h.engine.start(runId);

      expect(statusWhenEventLogged, RunStatus.succeeded);
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
        expect(h.run.status, RunStatus.cancelling);
        expect(h.eventTypes, contains(RunEventType.runCancelling));
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
      'a failed kill transitions to cancellationUncertain and is retryable',
      () async {
        final hung = Completer<void>();
        h.killer
          ..failure = const NodeExecutionFailure('still alive')
          ..onKill = (runId, nodeId) {
            if (h.killer.failure == null && !hung.isCompleted) hung.complete();
          };
        h.script.on('a', [outcomeAfter(hung.future, NodeOutput.onSuccess)]);
        await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));

        final started = h.engine.start(runId);
        await h.settle();
        final first = await h.engine.cancel(runId);

        expect(first.valueOrNull?.status, RunStatus.cancellationUncertain);
        expect(
          (await started).valueOrNull?.status,
          RunStatus.cancellationUncertain,
        );
        expect(h.run.status, RunStatus.cancellationUncertain);
        expect(h.eventTypes, contains(RunEventType.runCancelling));
        expect(h.eventTypes, contains(RunEventType.runCancellationUncertain));
        expect(h.eventTypes, isNot(contains(RunEventType.runCancelled)));
        expect(h.engine.isExecuting(runId), isFalse);

        h.killer.failure = null;
        final second = await h.engine.cancel(runId);

        expect(second.valueOrNull?.status, RunStatus.cancelled);
        expect(h.killer.kills, hasLength(2));
        expect(h.engine.isExecuting(runId), isFalse);
        expect(h.eventTypes.last, RunEventType.runCancelled);
      },
    );

    test('a cancel issued during start is applied once driven', () async {
      await h.createRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      final started = h.engine.start(runId);
      final cancelled = await h.engine.cancel(runId);

      expect(cancelled.valueOrNull?.status, RunStatus.cancelled);
      expect((await started).valueOrNull?.status, RunStatus.cancelled);
      expect(h.script.executions, isEmpty);
    });

    test(
      'a cancel issued during a failing setup reports that failure',
      () async {
        final started = h.engine.start('missing');
        final cancelled = await h.engine.cancel('missing');

        expect((await started).failureOrNull, isA<NotFoundFailure>());
        expect(cancelled.failureOrNull, isA<NotFoundFailure>());
      },
    );

    test(
      'a cancel that races the pause is applied to the paused run',
      () async {
        await h.createRun(
          buildWorkflow(
            nodeIds: ['gate'],
            approvals: {'gate'},
            edges: const [],
          ),
        );
        Future<Result<Run>>? cancelled;
        h.events.onAppend = (event) {
          if (event.type == RunEventType.runPaused) {
            cancelled = h.engine.cancel(runId);
          }
        };

        final started = await h.engine.start(runId);

        expect(started.valueOrNull?.status, RunStatus.cancelled);
        expect((await cancelled!).valueOrNull?.status, RunStatus.cancelled);
        expect(h.run.status, RunStatus.cancelled);
      },
    );

    test(
      'a cancel that arrives too late says the run already finished',
      () async {
        await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));
        Future<Result<Run>>? cancelled;
        h.events.onAppend = (event) {
          if (event.type == RunEventType.runSucceeded) {
            cancelled = h.engine.cancel(runId);
          }
        };

        final started = await h.engine.start(runId);
        final result = await cancelled!;

        expect(started.valueOrNull?.status, RunStatus.succeeded);
        expect(result.failureOrNull, isA<ConflictFailure>());
        expect(result.failureOrNull!.message, contains('succeeded'));
        expect(h.run.status, RunStatus.succeeded);
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
