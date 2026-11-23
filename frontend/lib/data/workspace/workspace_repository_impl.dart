import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [WorkspaceRepository] backed by [WorkspaceRemoteDataSource].
final class WorkspaceRepositoryImpl implements WorkspaceRepository {
  /// Creates a [WorkspaceRepositoryImpl] delegating to [_remote].
  const new(this._remote);

  final WorkspaceRemoteDataSource _remote;

  @override
  Future<Result<WorkspaceCapabilities>> getCapabilities({String? path}) =>
      _remote.getCapabilities(path: path);

  @override
  Future<Result<List<Snapshot>>> listSnapshots(String runId) =>
      _remote.listSnapshots(runId);

  @override
  Future<Result<SnapshotDiff>> getSnapshotDiff(
    String runId,
    String snapshotId,
  ) => _remote.getSnapshotDiff(runId, snapshotId);

  @override
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId,
  ) => _remote.restoreSnapshot(runId, snapshotId);
}
