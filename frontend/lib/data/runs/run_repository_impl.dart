import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/runs_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [RunRepository] backed by [RunsRemoteDataSource].
final class RunRepositoryImpl implements RunRepository {
  /// Creates a [RunRepositoryImpl] delegating to [_remoteDataSource].
  const new(this._remoteDataSource);

  final RunsRemoteDataSource _remoteDataSource;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) => _remoteDataSource.listRuns(
    status: status,
    workflowId: workflowId,
    workspaceId: workspaceId,
    limit: limit,
    offset: offset,
  );

  @override
  Future<Result<Run>> getRun(String id) => _remoteDataSource.getRun(id);

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) => _remoteDataSource.getRunEvents(
    id,
    afterSequence: afterSequence,
    limit: limit,
  );

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) =>
      _remoteDataSource.getRunCheckpoints(id);

  @override
  Future<Result<Run>> startRun(StartRunRequest request) =>
      _remoteDataSource.startRun(request);

  @override
  Future<Result<Run>> cancelRun(String id) => _remoteDataSource.cancelRun(id);

  @override
  Future<Result<Run>> resumeRun(String id) => _remoteDataSource.resumeRun(id);

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) => _remoteDataSource.getNodeLogs(id, nodeId, attempt: attempt, tail: tail);

  @override
  Future<Result<void>> deleteRun(String id) => _remoteDataSource.deleteRun(id);
}
