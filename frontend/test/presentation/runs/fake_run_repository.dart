import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Minimal [RunRepository] test double returning one configurable run.
final class FakeRunRepository implements RunRepository {
  new({
    this.status = RunStatus.failed,
    this.isolationMode = WorkspaceIsolationMode.direct,
    this.worktreePath,
    this.worktreeBranch,
    this.checkpoints = const <Checkpoint>[],
  });

  final RunStatus status;
  final WorkspaceIsolationMode isolationMode;
  final String? worktreePath;
  final String? worktreeBranch;
  final List<Checkpoint> checkpoints;

  int getRunCalls = 0;

  static final DateTime _now = DateTime.utc(2026, 11, 21, 4, 30);

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async {
    getRunCalls++;
    return Success(
      Run(
        id: id,
        workflowId: 'wf-1',
        workflowName: 'Release Build',
        workflowDefinition: Workflow(
          id: 'wf-1',
          name: 'Release Build',
          nodes: const <WorkflowNode>[
            WorkflowNode(
              id: 'node-build',
              type: 'command',
              label: 'Build step',
              position: WorkflowPosition(x: 0, y: 0),
            ),
          ],
          edges: const <WorkflowEdge>[],
          createdAt: _now,
          updatedAt: _now,
        ),
        workspaceRoot: '/projects/hive',
        status: status,
        startedAt: _now,
        isolationMode: isolationMode,
        worktreePath: worktreePath,
        worktreeBranch: worktreeBranch,
      ),
    );
  }

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async =>
      const Success(RunEventsResponse(items: <RunEvent>[], lastSequence: 0));

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      Success(checkpoints);

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> cancelRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> resumeRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async => Success(
    RunNodeLogsResponse(runId: id, nodeId: nodeId, attempt: attempt ?? 1),
  );

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}
