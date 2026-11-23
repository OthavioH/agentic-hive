import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agents_migration_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Loads the conflicts left by the move of the global agents.
final class GetAgentsMigrationStatusUseCase {
  /// Creates a [GetAgentsMigrationStatusUseCase].
  const new(this._repository);

  final AgentsMigrationRepository _repository;

  /// Fetches the current migration status.
  Future<Result<AgentsMigrationStatus>> call() => _repository.getStatus();
}
