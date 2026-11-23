import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for the move of the global agents into
/// `~/.agents/agents` (ADR 0025).
abstract interface class AgentsMigrationRepository {
  /// Loads the conflicts the move left behind.
  Future<Result<AgentsMigrationStatus>> getStatus();

  /// Remembers that the user saw the current conflicts.
  Future<Result<AgentsMigrationStatus>> dismiss();
}
