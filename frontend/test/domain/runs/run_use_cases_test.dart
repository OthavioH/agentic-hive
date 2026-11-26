import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeRunRepository implements RunRepository {
  RunStatus? lastStatus;
  String? lastWorkflowId;
  String? lastWorkspaceId;
  int? lastLimit;
  int? lastOffset;
  String? lastId;
  int? lastAfterSequence;

  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async {
    lastStatus = status;
    lastWorkflowId = workflowId;
    lastWorkspaceId = workspaceId;
    lastLimit = limit;
    lastOffset = offset;
    return const Success(RunsListResponse(items: <RunSummary>[], total: 0));
  }

  @override
  Future<Result<Run>> getRun(String id) async {
    lastId = id;
    return Success(
      Run(
        id: id,
        workflowName: 'Test',
        workflowDefinition: Workflow(
          id: 'wf-1',
          name: 'Test',
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        workspaceRoot: '/tmp',
        status: RunStatus.succeeded,
        startedAt: now,
      ),
    );
  }

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async {
    lastId = id;
    lastAfterSequence = afterSequence;
    lastLimit = limit;
    return const Success(
      RunEventsResponse(items: <RunEvent>[], lastSequence: 0),
    );
  }

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async {
    lastId = id;
    return const Success(<Checkpoint>[]);
  }

  String? lastNodeId;
  int? lastAttempt;
  int? lastTail;
  StartRunRequest? lastStartRequest;

  @override
  Future<Result<Run>> startRun(StartRunRequest request) {
    lastStartRequest = request;
    return getRun('run-started');
  }

  @override
  Future<Result<Run>> cancelRun(String id) {
    lastId = id;
    return getRun(id);
  }

  @override
  Future<Result<Run>> resumeRun(String id) {
    lastId = id;
    return getRun(id);
  }

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async {
    lastId = id;
    lastNodeId = nodeId;
    lastAttempt = attempt;
    lastTail = tail;
    return Success(
      RunNodeLogsResponse(runId: id, nodeId: nodeId, attempt: attempt ?? 1),
    );
  }

  @override
  Future<Result<void>> deleteRun(String id) async {
    lastId = id;
    return const Success(null);
  }
}

void main() {
  group('Run use cases', () {
    test('delegate all operations to RunRepository', () async {
      final repo = _FakeRunRepository();
      final container = ProviderContainer.test(
        overrides: [runRepositoryProvider.overrideWithValue(repo)],
      );

      final listRes = await container
          .read(listRunsProvider)
          .call(
            status: RunStatus.failed,
            workflowId: 'wf-1',
            workspaceId: 'ws-1',
            limit: 10,
            offset: 2,
          );
      expect(listRes.isSuccess, isTrue);
      expect(repo.lastStatus, RunStatus.failed);
      expect(repo.lastWorkflowId, 'wf-1');
      expect(repo.lastWorkspaceId, 'ws-1');
      expect(repo.lastLimit, 10);
      expect(repo.lastOffset, 2);

      final getRes = await container.read(getRunProvider).call('run-1');
      expect(getRes.valueOrNull?.id, 'run-1');
      expect(repo.lastId, 'run-1');

      final eventsRes = await container
          .read(getRunEventsProvider)
          .call('run-1', afterSequence: 3, limit: 50);
      expect(eventsRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-1');
      expect(repo.lastAfterSequence, 3);
      expect(repo.lastLimit, 50);

      final cpRes = await container
          .read(getRunCheckpointsProvider)
          .call('run-1');
      expect(cpRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-1');

      final delRes = await container.read(deleteRunProvider).call('run-1');
      expect(delRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-1');

      const startReq = StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        workspaceIsolationMode: WorkspaceIsolationMode.worktree,
      );
      final startRes = await container.read(startRunProvider).call(startReq);
      expect(startRes.isSuccess, isTrue);
      expect(repo.lastStartRequest, startReq);

      final cancelRes = await container.read(cancelRunProvider).call('run-2');
      expect(cancelRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-2');

      final resumeRes = await container.read(resumeRunProvider).call('run-3');
      expect(resumeRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-3');

      final logsRes = await container
          .read(getNodeLogsProvider)
          .call('run-1', 'node-1', attempt: 2, tail: 100);
      expect(logsRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-1');
      expect(repo.lastNodeId, 'node-1');
      expect(repo.lastAttempt, 2);
      expect(repo.lastTail, 100);
    });
  });
}
