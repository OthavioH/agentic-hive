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
  Future<Result<List<Workspace>>> listWorkspaces() => _remote.listWorkspaces();

  @override
  Future<Result<Workspace>> createWorkspace({
    required String rootPath,
    String? name,
  }) => _remote.createWorkspace(
    CreateWorkspaceRequest(rootPath: rootPath, name: name),
  );

  @override
  Future<Result<Workspace>> renameWorkspace(
    String id, {
    required String name,
  }) => _remote.renameWorkspace(id, UpdateWorkspaceRequest(name: name));

  @override
  Future<Result<void>> unregisterWorkspace(String id) =>
      _remote.unregisterWorkspace(id);

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
