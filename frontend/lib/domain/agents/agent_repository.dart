import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for managing the user's Agent library (`.md` files).
abstract interface class AgentRepository {
  /// Lists the global agents, or with [workspaceId] that workspace's agents
  /// plus the global ones, including malformed files with
  /// [AgentSummary.parseError].
  Future<Result<List<AgentSummary>>> listAgents({String? workspaceId});

  /// Loads the full detail for the agent with [id], resolving the workspace
  /// folder first when [workspaceId] is set.
  Future<Result<AgentDetail>> getAgent(String id, {String? workspaceId});

  /// Creates a new agent `.md` file in the global library, or in the
  /// workspace folder when [workspaceId] is set.
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    String? workspaceId,
  });

  /// Updates an existing agent `.md` file, checking
  /// [UpdateAgentRequest.expectedHash].
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    String? workspaceId,
  });

  /// Deletes the agent `.md` file with [id].
  Future<Result<void>> deleteAgent(String id, {String? workspaceId});

  /// Emits real-time filesystem change events for agents.
  Stream<AgentsChangedPayload> watchAgentChanges();
}
