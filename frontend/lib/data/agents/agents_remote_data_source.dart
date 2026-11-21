import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source communicating with `/api/v1/agents` via [BackendClient].
final class AgentsRemoteDataSource {
  /// Creates an [AgentsRemoteDataSource].
  const new(this._client);

  static const String _basePath = '/api/v1/agents';

  final BackendClient _client;

  /// Fetches all agent summaries (`GET /api/v1/agents`).
  Future<Result<List<AgentSummary>>> listAgents() async {
    final result = await _client.getJson(_basePath);
    return result.flatMap(_decodeList);
  }

  /// Fetches full detail for agent [id] (`GET /api/v1/agents/<id>`).
  Future<Result<AgentDetail>> getAgent(String id) async {
    final result = await _client.getJson(
      '$_basePath/${Uri.encodeComponent(id)}',
    );
    return result.flatMap(_decodeDetail);
  }

  /// Creates an agent (`POST /api/v1/agents`).
  Future<Result<AgentDetail>> createAgent(CreateAgentRequest request) async {
    final result = await _client.postJson(_basePath, request.toJson());
    return result.flatMap(_decodeDetail);
  }

  /// Updates an agent (`PUT /api/v1/agents/<id>`).
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request,
  ) async {
    final result = await _client.putJson(
      '$_basePath/${Uri.encodeComponent(id)}',
      request.toJson(),
    );
    return result.flatMap(_decodeDetail);
  }

  /// Deletes an agent (`DELETE /api/v1/agents/<id>`).
  Future<Result<void>> deleteAgent(String id) =>
      _client.delete('$_basePath/${Uri.encodeComponent(id)}');

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
