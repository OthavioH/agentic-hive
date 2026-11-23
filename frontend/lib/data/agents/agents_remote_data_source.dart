import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source communicating with `/api/v1/agents` via [BackendClient].
final class AgentsRemoteDataSource {
  /// Creates an [AgentsRemoteDataSource].
  const new(this._client);

  static const String _basePath = '/api/v1/agents';

  final BackendClient _client;

  /// Appends the `workspaceId` query parameter when [workspaceId] is set.
  ///
  /// Without it the backend serves the global library only.
  static String _scoped(String path, String? workspaceId) => workspaceId == null
      ? path
      : '$path?workspaceId=${Uri.encodeComponent(workspaceId)}';

  /// Fetches agent summaries (`GET /api/v1/agents`): the global library, or
  /// with [workspaceId] that workspace's agents plus the global ones.
  Future<Result<List<AgentSummary>>> listAgents({String? workspaceId}) async {
    final result = await _client.getJson(_scoped(_basePath, workspaceId));
    return result.flatMap(_decodeList);
  }

  /// Fetches full detail for agent [id] (`GET /api/v1/agents/<id>`).
  Future<Result<AgentDetail>> getAgent(String id, {String? workspaceId}) async {
    final result = await _client.getJson(
      _scoped('$_basePath/${Uri.encodeComponent(id)}', workspaceId),
    );
    return result.flatMap(_decodeDetail);
  }

  /// Creates an agent (`POST /api/v1/agents`).
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    String? workspaceId,
  }) async {
    final result = await _client.postJson(
      _scoped(_basePath, workspaceId),
      body: request.toJson(),
    );
    return result.flatMap(_decodeDetail);
  }

  /// Updates an agent (`PUT /api/v1/agents/<id>`).
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    String? workspaceId,
  }) async {
    final result = await _client.putJson(
      _scoped('$_basePath/${Uri.encodeComponent(id)}', workspaceId),
      request.toJson(),
    );
    return result.flatMap(_decodeDetail);
  }

  /// Deletes an agent (`DELETE /api/v1/agents/<id>`).
  Future<Result<void>> deleteAgent(String id, {String? workspaceId}) => _client
      .delete(_scoped('$_basePath/${Uri.encodeComponent(id)}', workspaceId));

  Result<List<AgentSummary>> _decodeList(JsonMap json) {
    try {
      return Success(AgentListResponse.fromJson(json).agents);
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Invalid agent list response: ${error.message}'),
      );
    }
  }

  Result<AgentDetail> _decodeDetail(JsonMap json) {
    try {
      return Success(AgentDetail.fromJson(json));
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Invalid agent detail response: ${error.message}'),
      );
    }
  }
}
