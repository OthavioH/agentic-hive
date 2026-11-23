import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agents_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [AgentRepository] backed by [AgentsRemoteDataSource] and a WebSocket
/// change stream.
final class AgentRepositoryImpl implements AgentRepository {
  /// Creates an [AgentRepositoryImpl].
  const new({required this._remoteDataSource, required this._changesStream});

  final AgentsRemoteDataSource _remoteDataSource;
  final Stream<AgentsChangedPayload> _changesStream;

  @override
  Future<Result<List<AgentSummary>>> listAgents({String? workspaceId}) =>
      _remoteDataSource.listAgents(workspaceId: workspaceId);

  @override
  Future<Result<AgentDetail>> getAgent(String id, {String? workspaceId}) =>
      _remoteDataSource.getAgent(id, workspaceId: workspaceId);

  @override
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    String? workspaceId,
  }) => _remoteDataSource.createAgent(request, workspaceId: workspaceId);

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    String? workspaceId,
  }) => _remoteDataSource.updateAgent(id, request, workspaceId: workspaceId);

  @override
  Future<Result<void>> deleteAgent(String id, {String? workspaceId}) =>
      _remoteDataSource.deleteAgent(id, workspaceId: workspaceId);

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() => _changesStream;
}
