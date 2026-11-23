import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';

/// Gives access to the agent library inside a workspace's root folder
/// (`<root>/.agents/agents`, ADR 0022).
abstract interface class WorkspaceAgentRepositories {
  /// The agent repository of the workspace rooted at [workspaceRoot].
  AgentRepository forRoot(String workspaceRoot);

  /// The agent repository of the registered workspace [workspaceId], or
  /// `NotFoundFailure` when no such workspace exists.
  Future<Result<AgentRepository>> forWorkspaceId(String workspaceId);
}
