import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agents_migration_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Marks the conflicts of the global agents move as seen.
final class DismissAgentsMigrationUseCase {
  /// Creates a [DismissAgentsMigrationUseCase].
  const new(this._repository);

  final AgentsMigrationRepository _repository;

  /// Dismisses the current conflicts and returns the updated status.
  Future<Result<AgentsMigrationStatus>> call() => _repository.dismiss();
}
