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

  @override
  Future<Result<Run>> cancel(String runId) async {
    calls.add(runId);
    return runs.updateStatus(
      runId,
      status: RunStatus.cancelled,
      finishedAt: DateTime.utc(2026, 11, 20, 10, 5),
    );
  }
}

void main() {
  final sampleWorkflow = Workflow(
    id: 'wf-parent',
    name: 'Parent Flow',
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
    String? parentRunId,
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
    parentRunId: parentRunId,
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

  test('deleteRun cleans logs of the run and of every child', () async {
    await runs.create(
      makeRun(id: 'p', workflowId: 'wf-parent', status: RunStatus.succeeded),
    );
    await runs.create(
      makeRun(
        id: 'c1',
        workflowId: 'wf-child',
        status: RunStatus.succeeded,
        parentRunId: 'p',
      ),
    );
    await runs.create(
      makeRun(
        id: 'c2',
        workflowId: 'wf-child',
        status: RunStatus.failed,
        parentRunId: 'p',
      ),
    );

    final res = await service.deleteRun('p');
    expect(res.isSuccess, isTrue);
    expect(logStore.deletedRunIds, ['c1', 'c2', 'p']);
    expect(runs.runs, isEmpty);
  });

  test('deleteRun refuses when a child is active and cleans nothing', () async {
    await runs.create(
      makeRun(id: 'p', workflowId: 'wf-parent', status: RunStatus.succeeded),
    );
    await runs.create(
      makeRun(
        id: 'c1',
        workflowId: 'wf-child',
        status: RunStatus.running,
        parentRunId: 'p',
      ),
    );

    final res = await service.deleteRun('p');
    expect(res.failureOrNull, isA<ConflictFailure>());
    expect(logStore.deletedRunIds, isEmpty);
    expect(runs.runs.keys, containsAll(['p', 'c1']));
  });

  test(
    'activeRunsOfWorkflow includes children of the workflow runs, oldest first',
    () async {
      final t0 = DateTime.utc(2026, 11, 20, 10);
      await runs.create(
        makeRun(
          id: 'p',
          workflowId: 'wf-parent',
          status: RunStatus.succeeded,
          startedAt: t0,
        ),
      );
      await runs.create(
        makeRun(
          id: 'c1',
          workflowId: 'wf-child',
          status: RunStatus.running,
          parentRunId: 'p',
          startedAt: t0.add(const Duration(seconds: 2)),
        ),
      );
      await runs.create(
        makeRun(
          id: 'c0',
          workflowId: 'wf-child',
          status: RunStatus.paused,
          parentRunId: 'p',
          startedAt: t0.add(const Duration(seconds: 1)),
        ),
      );

      final parentActive = await service.activeRunsOfWorkflow('wf-parent');
      expect(parentActive.valueOrNull!.keys, ['c0', 'c1']);

      final childActive = await service.activeRunsOfWorkflow('wf-child');
      expect(childActive.valueOrNull!.keys, ['c0', 'c1']);
    },
  );

  test(
    'activeRunsOfWorkflow respects the workspace scope for children',
    () async {
      await runs.create(
        makeRun(
          id: 'p1',
          workflowId: 'wf-parent',
          workspaceId: 'ws-1',
          status: RunStatus.succeeded,
        ),
      );
      await runs.create(
        makeRun(
          id: 'c1',
          workflowId: 'wf-child',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          parentRunId: 'p1',
        ),
      );
      await runs.create(
        makeRun(
          id: 'p2',
          workflowId: 'wf-parent',
          workspaceId: 'ws-2',
          status: RunStatus.succeeded,
        ),
      );
      await runs.create(
        makeRun(
          id: 'c2',
          workflowId: 'wf-child',
          workspaceId: 'ws-2',
          status: RunStatus.running,
          parentRunId: 'p2',
        ),
      );

      final res = await service.activeRunsOfWorkflow(
        'wf-parent',
        workspaceId: 'ws-1',
      );
      expect(res.valueOrNull!.keys, ['c1']);
    },
  );

  test(
    'deleteRunsOfWorkflow deletes children, cleans their logs and counts them',
    () async {
      await runs.create(
        makeRun(id: 'p', workflowId: 'wf-parent', status: RunStatus.succeeded),
      );
      await runs.create(
        makeRun(
          id: 'c1',
          workflowId: 'wf-child',
          status: RunStatus.succeeded,
          parentRunId: 'p',
        ),
      );
      await runs.create(
        makeRun(
          id: 'c2',
          workflowId: 'wf-child',
          status: RunStatus.failed,
          parentRunId: 'p',
        ),
      );

      final res = await service.deleteRunsOfWorkflow('wf-parent');
      expect(res.valueOrNull!.deletedRuns, 3);
      expect(logStore.deletedRunIds, ['p', 'c1', 'c2']);
      expect(runs.runs, isEmpty);
    },
  );

  test(
    'deleteRunsOfWorkflow without force fails with children in the active map',
    () async {
      await runs.create(
        makeRun(id: 'p', workflowId: 'wf-parent', status: RunStatus.succeeded),
      );
      await runs.create(
        makeRun(
          id: 'c1',
          workflowId: 'wf-child',
          status: RunStatus.running,
          parentRunId: 'p',
        ),
      );

      final res = await service.deleteRunsOfWorkflow('wf-parent');
      final failure = res.failureOrNull! as WorkflowHasActiveRunsFailure;
      expect(failure.activeRuns.keys, ['c1']);
    },
  );

  test(
    'forced deleteRunsOfWorkflow cancels the active parent and its active child',
    () async {
      final t0 = DateTime.utc(2026, 11, 20, 10);
      await runs.create(
        makeRun(
          id: 'p',
          workflowId: 'wf-parent',
          status: RunStatus.running,
          startedAt: t0,
        ),
      );
      await runs.create(
        makeRun(
          id: 'c1',
          workflowId: 'wf-child',
          status: RunStatus.running,
          parentRunId: 'p',
          startedAt: t0.add(const Duration(seconds: 1)),
        ),
      );

      final res = await service.deleteRunsOfWorkflow('wf-parent', force: true);
      expect(res.valueOrNull!.deletedRuns, 2);
      expect(canceller.calls, ['p', 'c1']);
      expect(runs.runs, isEmpty);
    },
  );

  test(
    'deleteRunsOfWorkflow keeps a pre-existing uncertain child as an orphan and does not delete it',
    () async {
      await runs.create(
        makeRun(id: 'p', workflowId: 'wf-parent', status: RunStatus.succeeded),
      );
      await runs.create(
        makeRun(
          id: 'c-uncertain',
          workflowId: 'wf-child',
          status: RunStatus.cancellationUncertain,
          parentRunId: 'p',
        ),
      );

      final res = await service.deleteRunsOfWorkflow('wf-parent');
      expect(res.valueOrNull!.deletedRuns, 1);
      expect(res.valueOrNull!.orphanedRuns, ['c-uncertain']);
      final orphan = runs.runs['c-uncertain']!;
      expect(orphan.workflowId, isNull);
      expect(orphan.parentRunId, isNull);
    },
  );
}
