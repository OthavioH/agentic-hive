import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
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
  }) => Run(
    id: id,
    workflowId: workflowId,
    workflowName: sampleWorkflow.name,
    workflowDefinition: sampleWorkflow,
    workspaceId: workspaceId,
    workspacePath: '/tmp/ws',
    status: status,
    startedAt: DateTime.utc(2026, 11, 20, 10),
  );

  late InMemoryRunRepository runs;
  late _RecordingLogStore logStore;
  late RunService service;

  setUp(() {
    runs = InMemoryRunRepository();
    logStore = _RecordingLogStore();
    service = RunService(
      runs: runs,
      checkpoints: InMemoryCheckpointRepository(),
      events: InMemoryRunEventRepository(),
      logStore: logStore,
    );
  });

  test(
    'deletes runs of the workflow, cleans their logs and returns the count',
    () async {
      await runs.create(
        makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.succeeded),
      );
      await runs.create(
        makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.failed),
      );
      await runs.create(
        makeRun(id: 'r3', workflowId: 'wf-2', status: RunStatus.succeeded),
      );

      final result = await service.deleteRunsOfWorkflow('wf-1');

      expect(result.valueOrNull?.deletedRuns, 2);
      expect(result.valueOrNull?.orphanedRuns, isEmpty);
      expect(logStore.deletedRunIds.toSet(), {'r1', 'r2'});
      expect(runs.runs.keys, ['r3']);
    },
  );

  test('returns WorkflowHasActiveRunsFailure and cleans nothing '
      'when a run is active', () async {
    await runs.create(
      makeRun(id: 'r1', workflowId: 'wf-1', status: RunStatus.succeeded),
    );
    await runs.create(
      makeRun(id: 'r2', workflowId: 'wf-1', status: RunStatus.running),
    );

    final result = await service.deleteRunsOfWorkflow('wf-1');

    expect(result.failureOrNull, isA<WorkflowHasActiveRunsFailure>());
    expect(logStore.deletedRunIds, isEmpty);
    expect(runs.runs.keys.toSet(), {'r1', 'r2'});
  });

  test('passes the workspace scope through', () async {
    await runs.create(
      makeRun(
        id: 'r1',
        workflowId: 'review',
        workspaceId: 'ws-a',
        status: RunStatus.succeeded,
      ),
    );
    await runs.create(
      makeRun(
        id: 'r2',
        workflowId: 'review',
        workspaceId: 'ws-b',
        status: RunStatus.succeeded,
      ),
    );

    final result = await service.deleteRunsOfWorkflow(
      'review',
      workspaceId: 'ws-a',
    );

    expect(result.valueOrNull?.deletedRuns, 1);
    expect(result.valueOrNull?.orphanedRuns, isEmpty);
    expect(logStore.deletedRunIds, ['r1']);
    expect(runs.runs.keys, ['r2']);
  });

  test(
    'activeRunsOfWorkflow batches parent lookups without per-run getById',
    () async {
      final countingRuns = InMemoryRunRepository();
      final batchService = RunService(
        runs: countingRuns,
        checkpoints: InMemoryCheckpointRepository(),
        events: InMemoryRunEventRepository(),
      );
      await countingRuns.create(
        makeRun(id: 'p1', workflowId: 'wf-1', status: RunStatus.running),
      );
      await countingRuns.create(
        makeRun(id: 'p2', workflowId: 'wf-1', status: RunStatus.running),
      );
      await countingRuns.create(
        makeRun(
          id: 'c1',
          workflowId: 'wf-child',
          status: RunStatus.running,
        ).copyWith(parentRunId: 'p1'),
      );
      await countingRuns.create(
        makeRun(
          id: 'c2',
          workflowId: 'wf-child',
          status: RunStatus.paused,
        ).copyWith(parentRunId: 'p2'),
      );

      final result = await batchService.activeRunsOfWorkflow('wf-1');

      expect(result.valueOrNull?.keys.toSet(), {'p1', 'p2', 'c1', 'c2'});
      expect(countingRuns.getByIdCalls, 0);
    },
  );
}
