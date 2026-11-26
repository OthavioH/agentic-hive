import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Deletes an agent from the library.
final class DeleteAgentUseCase {
  /// Creates a [DeleteAgentUseCase].
  const new(this._repository);

  final AgentRepository _repository;

  /// Deletes the agent with [id] from [scope].
  Future<Result<void>> call(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) => _repository.deleteAgent(id, scope: scope);
}
