import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Updates an existing agent in the library.
final class UpdateAgentUseCase {
  /// Creates an [UpdateAgentUseCase].
  const new(this._repository);

  final AgentRepository _repository;

  /// Persists updates to agent [id] using [request].
  Future<Result<AgentDetail>> call({
    required String id,
    required UpdateAgentRequest request,
    String? workspaceId,
  }) => _repository.updateAgent(id, request, workspaceId: workspaceId);
}
