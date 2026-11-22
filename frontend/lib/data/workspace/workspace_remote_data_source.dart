import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source for workspace registry, capabilities and snapshots.
abstract interface class WorkspaceRemoteDataSource {
  /// `GET /api/v1/workspaces`.
  Future<Result<List<Workspace>>> listWorkspaces();

  /// `POST /api/v1/workspaces`.
  Future<Result<Workspace>> createWorkspace(CreateWorkspaceRequest request);

  /// `PATCH /api/v1/workspaces/:id`.
  Future<Result<Workspace>> renameWorkspace(
    String id,
    UpdateWorkspaceRequest request,
  );

  /// `DELETE /api/v1/workspaces/:id`.
  Future<Result<void>> unregisterWorkspace(String id);

  /// `GET /api/v1/workspace/capabilities`.
  Future<Result<WorkspaceCapabilities>> getCapabilities({String? path});

  /// `GET /api/v1/runs/:id/snapshots`.
  Future<Result<List<Snapshot>>> listSnapshots(String runId);

  /// `GET /api/v1/runs/:id/snapshots/:snapshotId/diff`.
  Future<Result<SnapshotDiff>> getSnapshotDiff(String runId, String snapshotId);

  /// `POST /api/v1/runs/:id/snapshots/:snapshotId/restore`.
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId,
  );
}

/// [WorkspaceRemoteDataSource] backed by [BackendClient].
final class HttpWorkspaceRemoteDataSource implements WorkspaceRemoteDataSource {
  /// Creates an HTTP workspace data source using [_client].
  const new(this._client);

  final BackendClient _client;

  @override
  Future<Result<List<Workspace>>> listWorkspaces() async {
    final result = await _client.sendJsonRequest('GET', '/api/v1/workspaces');
    return _decode(
      result,
      (json) => WorkspaceListResponse.fromJson(json).items,
    );
  }

  @override
  Future<Result<Workspace>> createWorkspace(
    CreateWorkspaceRequest request,
  ) async {
    final result = await _client.sendJsonRequest(
      'POST',
      '/api/v1/workspaces',
      body: request.toJson(),
    );
    return _decode(result, Workspace.fromJson);
  }

  @override
  Future<Result<Workspace>> renameWorkspace(
    String id,
    UpdateWorkspaceRequest request,
  ) async {
    final result = await _client.sendJsonRequest(
      'PATCH',
      '/api/v1/workspaces/${Uri.encodeComponent(id)}',
      body: request.toJson(),
    );
    return _decode(result, Workspace.fromJson);
  }

  @override
  Future<Result<void>> unregisterWorkspace(String id) async {
    final result = await _client.sendJsonRequest(
      'DELETE',
      '/api/v1/workspaces/${Uri.encodeComponent(id)}',
    );
    return result.map((_) {});
  }

  @override
  Future<Result<WorkspaceCapabilities>> getCapabilities({String? path}) async {
    final uri = Uri(
      path: '/api/v1/workspace/capabilities',
      queryParameters: path == null || path.isEmpty
          ? null
          : <String, String>{'path': path},
    );
    final result = await _client.sendJsonRequest('GET', uri.toString());
    return _decode(result, WorkspaceCapabilities.fromJson);
  }

  @override
  Future<Result<List<Snapshot>>> listSnapshots(String runId) async {
    final result = await _client.sendJsonRequest(
      'GET',
      '${_runPath(runId)}/snapshots',
    );
    return _decode(result, (json) => RunSnapshotsResponse.fromJson(json).items);
  }

  @override
  Future<Result<SnapshotDiff>> getSnapshotDiff(
    String runId,
    String snapshotId,
  ) async {
    final result = await _client.sendJsonRequest(
      'GET',
      '${_runPath(runId)}/snapshots/${Uri.encodeComponent(snapshotId)}/diff',
    );
    return _decode(result, SnapshotDiff.fromJson);
  }

  @override
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId,
  ) async {
    final result = await _client.sendJsonRequest(
      'POST',
      '${_runPath(runId)}/snapshots/${Uri.encodeComponent(snapshotId)}/restore',
    );
    return _decode(result, RestoreSnapshotResponse.fromJson);
  }

  String _runPath(String runId) => '/api/v1/runs/${Uri.encodeComponent(runId)}';

  Result<T> _decode<T>(
    Result<JsonMap> result,
    T Function(JsonMap json) parser,
  ) {
    return result.flatMap((json) {
      try {
        return Success<T>(parser(json));
      } on FormatException catch (error) {
        return FailureResult<T>(
          BackendFailure('Invalid workspace payload: ${error.message}'),
        );
      }
    });
  }
}
