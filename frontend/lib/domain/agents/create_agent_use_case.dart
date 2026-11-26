import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Creates a new agent in the library.
final class CreateAgentUseCase {
  /// Creates a [CreateAgentUseCase].
  const new(this._repository);

  final AgentRepository _repository;

  /// Persists a new agent described by [request] in [scope].
  Future<Result<AgentDetail>> call(
    CreateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) => _repository.createAgent(request, scope: scope);
}
