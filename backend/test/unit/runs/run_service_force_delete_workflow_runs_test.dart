import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_canceller.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../engine/support/in_memory_repositories.dart';

final class _RecordingLogStore implements RunLogStore {
  final List<String> deletedRunIds = <String>[];

  @override
  Future<Result<void>> deleteRunLogs(String runId) async {
    deletedRunIds.add(runId);
    return const Success<void>(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _FakeRunCanceller implements RunCanceller {
  new(this.runs);

  final InMemoryRunRepository runs;
  final List<String> calls = <String>[];

  /// Status the run is moved to when its cancel completes (absent = unchanged).
  final Map<String, RunStatus> outcomes = <String, RunStatus>{};

  /// Result returned per run (absent = Success(run)).
  final Map<String, Failure> failures = <String, Failure>{};

  /// Runs whose cancel throws.
  final Set<String> throwing = <String>{};

  /// When set, every cancel waits for it before settling.
  Future<void>? gate;

  /// Called at the start of every cancel (used to simulate a race).
  Future<void> Function(String runId)? onCancel;

  @override
  Future<Result<Run>> cancel(String runId) async {
    calls.add(runId);
    if (onCancel case final hook?) await hook(runId);
    if (gate case final g?) await g;
    if (throwing.contains(runId)) throw StateError('boom');
    final status = outcomes[runId];
    if (status != null) await runs.updateStatus(runId, status: status);
    if (failures[runId] case final f?) return FailureResult(f);
    return await runs.getById(runId);
  }
}

void main() {
  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Step',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 9),
    updatedAt: DateTime.utc(2026, 11, 20, 9),
  );

  Run makeRun({
    required String id,
    required String workflowId,
    required RunStatus status,
    String? workspaceId,
    DateTime? startedAt,
  }) => Run(
    id: id,
    workflowId: workflowId,
    workflowName: sampleWorkflow.name,
    workflowDefinition: sampleWorkflow,
    workspaceId: workspaceId,
    workspacePath: '/tmp/ws',
    status: status,
    startedAt: startedAt ?? DateTime.utc(2026, 11, 20, 10),
  );

  late InMemoryRunRepository runs;
  late _RecordingLogStore logStore;
  late _FakeRunCanceller canceller;
  late RunService service;

  setUp(() {
    runs = InMemoryRunRepository();
    logStore = _RecordingLogStore();
    canceller = _FakeRunCanceller(runs);
    service = RunService(
      runs: runs,
      checkpoints: InMemoryCheckpointRepository(),
      events: InMemoryRunEventRepository(),
      logStore: logStore,
      canceller: canceller,
    );
  });

  test('without force: active runs fail and nothing is cancelled', () async {
    await runs.create(
      makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.running),
    );

    final result = await service.deleteRunsOfWorkflow('wf-1');

    expect(result.failureOrNull, isA<WorkflowHasActiveRunsFailure>());
    expect(canceller.calls, isEmpty);
    expect(runs.runs.keys, ['r1']);
  });

  test(
    'without force: pre-existing cancellationUncertain run is kept as orphan',
    () async {
      await runs.create(
        makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.succeeded),
      );
      await runs.create(
        makeRun(
          id: 'r2',
          workflowId: 'wf-1',
          status: RunStatus.cancellationUncertain,
        ),
      );

      final result = await service.deleteRunsOfWorkflow('wf-1');

      expect(result.valueOrNull?.deletedRuns, 1);
      expect(result.valueOrNull?.orphanedRuns, ['r2']);
      expect(canceller.calls, isEmpty);
      expect(runs.runs.keys, ['r2']);
      expect(runs.runs['r2']!.workflowId, isNull);
      expect(runs.runs['r2']!.workflowName, 'Flow');
      expect(logStore.deletedRunIds, ['r1']);
    },
  );

  test('force with no active runs never cancels', () async {
    await runs.create(
      makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.succeeded),
    );

    final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

    expect(result.valueOrNull?.deletedRuns, 1);
    expect(result.valueOrNull?.orphanedRuns, isEmpty);
    expect(canceller.calls, isEmpty);
  });

  test(
    'force: cancels every active run and deletes all settled runs',
    () async {
      await runs.create(
        makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.succeeded),
      );
      await runs.create(
        makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.running),
      );
      await runs.create(
        makeRun(id: 'r3', workflowId: 'wf-1', status: RunStatus.paused),
      );
      canceller.outcomes['r2'] = RunStatus.cancelled;
      canceller.outcomes['r3'] = RunStatus.cancelled;

      final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

      expect(result.valueOrNull?.deletedRuns, 3);
      expect(result.valueOrNull?.orphanedRuns, isEmpty);
      expect(canceller.calls.toSet(), {'r2', 'r3'});
      expect(runs.runs, isEmpty);
      expect(logStore.deletedRunIds.toSet(), {'r1', 'r2', 'r3'});
    },
  );

  test('force: deletes nothing until every cancel settled', () async {
    await runs.create(
      makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.running),
    );
    canceller.outcomes['r1'] = RunStatus.cancelled;
    final gate = Completer<void>();
    canceller.gate = gate.future;

    final pending = service.deleteRunsOfWorkflow('wf-1', force: true);
    await pumpEventQueue();

    expect(runs.runs.containsKey('r1'), isTrue);
    expect(logStore.deletedRunIds, isEmpty);

    gate.complete();
    final result = await pending;
    expect(result.valueOrNull?.deletedRuns, 1);
  });

  test(
    'force: a run ending in cancellationUncertain is kept as an orphan',
    () async {
      await runs.create(
        makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.succeeded),
      );
      await runs.create(
        makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.running),
      );
      await runs.create(
        makeRun(id: 'r3', workflowId: 'wf-1', status: RunStatus.running),
      );
      canceller.outcomes['r2'] = RunStatus.cancellationUncertain;
      canceller.outcomes['r3'] = RunStatus.cancelled;

      final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

      expect(result.valueOrNull?.deletedRuns, 2);
      expect(result.valueOrNull?.orphanedRuns, ['r2']);
      expect(runs.runs.keys, ['r2']);
      expect(runs.runs['r2']!.workflowId, isNull);
      expect(runs.runs['r2']!.workflowName, 'Flow');
      expect(logStore.deletedRunIds, isNot(contains('r2')));
    },
  );

  test(
    'force: pre-existing cancellationUncertain run is kept as an orphan',
    () async {
      await runs.create(
        makeRun(
          id: 'r1',
          workflowId: 'wf-1',
          status: RunStatus.cancellationUncertain,
          startedAt: DateTime.utc(2026, 11, 20, 10),
        ),
      );
      await runs.create(
        makeRun(
          id: 'r2',
          workflowId: 'wf-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 20, 11),
        ),
      );
      canceller.outcomes['r2'] = RunStatus.cancelled;

      final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

      expect(result.valueOrNull?.deletedRuns, 1);
      expect(result.valueOrNull?.orphanedRuns, ['r1']);
      expect(canceller.calls, ['r2']);
      expect(runs.runs.keys, ['r1']);
      expect(runs.runs['r1']!.workflowId, isNull);
      expect(runs.runs['r1']!.workflowName, 'Flow');
      expect(logStore.deletedRunIds, ['r2']);
    },
  );

  test('force: a run still active after a failed cancel is orphaned', () async {
    await runs.create(
      makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.running),
    );
    canceller.failures['r2'] = const ConflictFailure('not executing');

    final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

    expect(result.valueOrNull?.orphanedRuns, ['r2']);
    expect(runs.runs['r2']!.status, RunStatus.running);
    expect(runs.runs['r2']!.workflowId, isNull);
  });

  test('force: a cancel that throws keeps the run as an orphan', () async {
    await runs.create(
      makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.running),
    );
    canceller.throwing.add('r2');

    final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

    expect(result.valueOrNull?.orphanedRuns, ['r2']);
    expect(runs.runs['r2']!.workflowId, isNull);
  });

  test('force: a run that finished before the cancel is deleted', () async {
    await runs.create(
      makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.running),
    );
    canceller.outcomes['r2'] = RunStatus.succeeded;
    canceller.failures['r2'] = const ConflictFailure('finished');

    final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

    expect(result.valueOrNull?.deletedRuns, 1);
    expect(result.valueOrNull?.orphanedRuns, isEmpty);
    expect(runs.runs, isEmpty);
  });

  test('force: orphanedRuns are ordered oldest first', () async {
    await runs.create(
      makeRun(
        id: 'r2',
        workflowId: 'wf-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12, 2),
      ),
    );
    await runs.create(
      makeRun(
        id: 'r3',
        workflowId: 'wf-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12, 1),
      ),
    );
    canceller.outcomes['r2'] = RunStatus.cancellationUncertain;
    canceller.outcomes['r3'] = RunStatus.cancellationUncertain;

    final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

    expect(result.valueOrNull?.orphanedRuns, ['r3', 'r2']);
  });

  test(
    'force without a canceller returns UnexpectedFailure and deletes nothing',
    () async {
      final noCancellerService = RunService(
        runs: runs,
        checkpoints: InMemoryCheckpointRepository(),
        events: InMemoryRunEventRepository(),
        logStore: logStore,
      );
      await runs.create(
        makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.running),
      );

      final result = await noCancellerService.deleteRunsOfWorkflow(
        'wf-1',
        force: true,
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(runs.runs.keys, ['r1']);
    },
  );

  test(
    'force: a new active run in the final step returns 409 and orphans nothing',
    () async {
      await runs.create(
        makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.running),
      );
      canceller.outcomes['r2'] = RunStatus.cancellationUncertain;
      canceller.onCancel = (_) async {
        await runs.create(
          makeRun(
            id: 'r9',
            workflowId: 'wf-1',
            status: RunStatus.running,
            startedAt: DateTime.utc(2026, 11, 20, 13),
          ),
        );
      };

      final result = await service.deleteRunsOfWorkflow('wf-1', force: true);

      final failure = result.failureOrNull! as WorkflowHasActiveRunsFailure;
      expect(failure.activeRuns.keys.toList(), ['r9']);
      expect(runs.runs['r2']!.workflowId, 'wf-1');
    },
  );

  test(
    'an orphaned run can be cancelled again and deleted on its own',
    () async {
      await runs.create(
        makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.running),
      );
      canceller.outcomes['r2'] = RunStatus.cancellationUncertain;

      final deleted = await service.deleteRunsOfWorkflow('wf-1', force: true);
      expect(deleted.valueOrNull?.orphanedRuns, ['r2']);

      canceller.outcomes['r2'] = RunStatus.cancelled;
      final retried = await service.cancelRun('r2');
      expect(retried.valueOrNull?.status, RunStatus.cancelled);

      final removed = await service.deleteRun('r2');
      expect(removed.isSuccess, isTrue);
      expect(runs.runs, isEmpty);
      expect(logStore.deletedRunIds, contains('r2'));
    },
  );
}
