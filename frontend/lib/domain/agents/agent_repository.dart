import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for managing the user's Agent library (`.md` files).
abstract interface class AgentRepository {
  /// Lists all agents in the library, including malformed files with
  /// [AgentSummary.parseError].
  Future<Result<List<AgentSummary>>> listAgents();

  /// Loads the full detail for the agent with [id].
  Future<Result<AgentDetail>> getAgent(String id);

  /// Creates a new agent `.md` file.
  Future<Result<AgentDetail>> createAgent(CreateAgentRequest request);

  /// Updates an existing agent `.md` file, checking
  /// [UpdateAgentRequest.expectedHash].
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request,
  );

  /// Deletes the agent `.md` file with [id].
  Future<Result<void>> deleteAgent(String id);

  /// Emits real-time filesystem change events for agents.
  Stream<AgentsChangedPayload> watchAgentChanges();
}
