import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists all agents in the library.
final class ListAgentsUseCase {
  /// Creates a [ListAgentsUseCase].
  const new(this._repository);

  final AgentRepository _repository;

  /// Fetches the agent summaries: global only, or with [workspaceId] the
  /// workspace's agents plus the global ones.
  Future<Result<List<AgentSummary>>> call({String? workspaceId}) =>
      _repository.listAgents(workspaceId: workspaceId);
}
