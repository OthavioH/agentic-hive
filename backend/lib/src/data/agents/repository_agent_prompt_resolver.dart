import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/layered_agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [AgentPromptResolver] backed by [AgentRepository].
///
/// Reads the agent on every [resolvePrompt] call without caching so edits to
/// `.md` files on disk take effect on the next run.
///
/// When a workspace root is given, the workspace agent folder is searched
/// before the global library. A workspace file that exists but is broken
/// fails the lookup instead of silently falling back to the global agent.
///
/// Empty or whitespace-only prompts are rejected with a [ValidationFailure]
/// because a harness node referencing an agent with no prompt is a
/// configuration error.
final class RepositoryAgentPromptResolver implements AgentPromptResolver {
  /// Creates a resolver that reads agent prompts from [_repository], and from
  /// the repository [workspaceAgents] returns for a workspace root.
  const new(this._repository, {this.workspaceAgents});

  final AgentRepository _repository;

  /// Builds the agent repository of a workspace root, or `null` to use only
  /// the global library.
  final AgentRepository Function(String workspaceRoot)? workspaceAgents;

  @override
  Future<Result<String>> resolvePrompt(
    String agentId, {
    String? workspaceRoot,
  }) async {
    final result = await resolveAgent(agentId, workspaceRoot: workspaceRoot);
    return switch (result) {
      Success<ResolvedAgent>(:final value) => Success(value.prompt),
      FailureResult<ResolvedAgent>(:final failure) => FailureResult(failure),
    };
  }

  @override
  Future<Result<ResolvedAgent>> resolveAgent(
    String agentId, {
    String? workspaceRoot,
  }) async {
    final workspaceRepository = workspaceRoot == null
        ? null
        : workspaceAgents?.call(workspaceRoot);
    final repository = workspaceRepository == null
        ? _repository
        : LayeredAgentRepository(
            global: _repository,
            workspace: workspaceRepository,
          );
    final result = await repository.getById(agentId);
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
