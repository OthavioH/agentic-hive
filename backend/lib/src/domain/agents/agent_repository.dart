import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Builds the read view of a workspace agent library layered over the global
/// one (ADR 0022): workspace agents override global agents with the same
/// `name`. Reads follow the layering; writes go to [workspace] only.
typedef LayerAgentRepositories = AgentRepository Function({
  required AgentRepository global,
  required AgentRepository workspace,
});

/// Persistence boundary for the agent `.md` file library.
abstract interface class AgentRepository {
  /// Lists all `.md` files at the root of the agents folder.
  ///
  /// Malformed files are included with a non-null [AgentSummary.parseError].
  Future<Result<List<AgentSummary>>> list();

  /// Reads the agent with slug [id].
  ///
  /// Returns [AgentDetail.parseError] and [AgentDetail.rawContent] if the file
  /// exists on disk but cannot be parsed.
  Future<Result<AgentDetail>> getById(String id);

  /// Creates a new `<id>.md` file from [request].
  Future<Result<AgentDetail>> create(CreateAgentRequest request);

  /// Updates `<id>.md` from [request], enforcing
  /// [UpdateAgentRequest.expectedHash].
  Future<Result<AgentDetail>> update(String id, UpdateAgentRequest request);

  /// Deletes `<id>.md`.
  Future<Result<void>> delete(String id);
}
