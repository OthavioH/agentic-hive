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
  Future<Result<List<AgentSummary>>> listAgents() =>
      _remoteDataSource.listAgents();

  @override
  Future<Result<AgentDetail>> getAgent(String id) =>
      _remoteDataSource.getAgent(id);

  @override
  Future<Result<AgentDetail>> createAgent(CreateAgentRequest request) =>
      _remoteDataSource.createAgent(request);

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request,
  ) => _remoteDataSource.updateAgent(id, request);

  @override
  Future<Result<void>> deleteAgent(String id) =>
      _remoteDataSource.deleteAgent(id);

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() => _changesStream;
}
