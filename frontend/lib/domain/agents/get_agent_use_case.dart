import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Loads a single agent's full detail by ID.
final class GetAgentUseCase {
  /// Creates a [GetAgentUseCase].
  const new(this._repository);

  final AgentRepository _repository;

  /// Fetches the full detail for agent [id].
  Future<Result<AgentDetail>> call(String id) => _repository.getAgent(id);
}
