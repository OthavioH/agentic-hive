import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [AgentPromptResolver] backed by [AgentRepository].
///
/// Reads the agent on every [resolvePrompt] call without caching so edits to
/// `.md` files on disk take effect on the next run.
///
/// Empty or whitespace-only prompts are rejected with a [ValidationFailure]
/// because a harness node referencing an agent with no prompt is a
/// configuration error.
final class RepositoryAgentPromptResolver implements AgentPromptResolver {
  /// Creates a resolver that reads agent prompts from [_repository].
  const new(this._repository);

  final AgentRepository _repository;

  @override
  Future<Result<String>> resolvePrompt(String agentId) async {
    final result = await resolveAgent(agentId);
    return switch (result) {
      Success<ResolvedAgent>(:final value) => Success(value.prompt),
      FailureResult<ResolvedAgent>(:final failure) => FailureResult(failure),
    };
  }

  @override
  Future<Result<ResolvedAgent>> resolveAgent(String agentId) async {
    final result = await _repository.getById(agentId);
    if (result case FailureResult<AgentDetail>(:final failure)) {
      return FailureResult(failure);
    }

    final detail = result.valueOrNull!;
    final parseError = detail.parseError;
    if (parseError != null) {
      return FailureResult(
        ValidationFailure('Agent "$agentId" could not be parsed: $parseError'),
      );
    }

    if (detail.prompt.trim().isEmpty) {
      return FailureResult(
        ValidationFailure('Agent "$agentId" has an empty prompt.'),
      );
    }

    return Success(
      ResolvedAgent(
        prompt: detail.prompt,
        allowedTools: detail.allowedTools,
        deniedTools: detail.deniedTools,
      ),
    );
  }
}
