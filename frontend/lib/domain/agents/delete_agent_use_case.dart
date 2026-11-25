import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';

/// Deletes an agent from the library.
final class DeleteAgentUseCase {
  /// Creates a [DeleteAgentUseCase].
  const new(this._repository);

  final AgentRepository _repository;

  /// Deletes the agent with [id] from the workspace folder when [workspaceId]
  /// is set, and from the global library otherwise.
  Future<Result<void>> call(String id, {String? workspaceId}) =>
      _repository.deleteAgent(id, workspaceId: workspaceId);
}
