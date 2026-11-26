import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for managing the user's Agent library (`.md` files).
abstract interface class AgentRepository {
  /// Lists the global agents, or with [WorkspaceScope] that workspace's agents
  /// plus the global ones, including malformed files with
  /// [AgentSummary.parseError].
  Future<Result<List<AgentSummary>>> listAgents({
    DefinitionScope scope = const GlobalScope(),
  });

  /// Loads the full detail for the agent with [id], resolving the workspace
  /// folder first when [scope] is [WorkspaceScope].
  Future<Result<AgentDetail>> getAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  });

  /// Creates a new agent `.md` file in [scope].
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  });

  /// Updates an existing agent `.md` file in [scope], checking
  /// [UpdateAgentRequest.expectedHash].
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  });

  /// Deletes the agent `.md` file with [id] from [scope].
  Future<Result<void>> deleteAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  });

  /// Emits real-time filesystem change events for agents.
  Stream<AgentsChangedPayload> watchAgentChanges();
}
