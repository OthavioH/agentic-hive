import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source for per-workspace execution settings.
abstract interface class WorkspaceSettingsRemoteDataSource {
  /// `GET /api/v1/workspaces/:id/settings`.
  Future<Result<WorkspaceSettingsResponse>> getSettings(String workspaceId);

  /// `PUT /api/v1/workspaces/:id/settings`.
  Future<Result<WorkspaceSettingsResponse>> updateSettings(
    String workspaceId,
    ExecutionSettings overrides,
  );
}

/// [WorkspaceSettingsRemoteDataSource] backed by [BackendClient].
final class HttpWorkspaceSettingsRemoteDataSource
    implements WorkspaceSettingsRemoteDataSource {
  /// Creates an HTTP data source using [_client].
  const new(this._client);

  final BackendClient _client;

  @override
  Future<Result<WorkspaceSettingsResponse>> getSettings(
    String workspaceId,
  ) async {
    final result = await _client.sendJsonRequest('GET', _path(workspaceId));
    return _decode(result);
  }

  @override
  Future<Result<WorkspaceSettingsResponse>> updateSettings(
    String workspaceId,
    ExecutionSettings overrides,
  ) async {
    final body = overrides.toJson()..removeWhere((_, value) => value == null);
    final result = await _client.sendJsonRequest(
      'PUT',
      _path(workspaceId),
      body: body,
    );
    return _decode(result);
  }

  String _path(String workspaceId) =>
      '/api/v1/workspaces/${Uri.encodeComponent(workspaceId)}/settings';

  Result<WorkspaceSettingsResponse> _decode(Result<JsonMap> result) {
    return result.flatMap((json) {
      try {
        return Success<WorkspaceSettingsResponse>(
          WorkspaceSettingsResponse.fromJson(json),
        );
      } on FormatException catch (error) {
        return FailureResult<WorkspaceSettingsResponse>(
          BackendFailure('Invalid workspace settings: ${error.message}'),
        );
      }
    });
  }
}
