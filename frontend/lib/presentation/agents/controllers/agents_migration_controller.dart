import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agents_migration_controller.g.dart';

/// Holds the conflicts left by the move of the global agents (ADR 0025).
///
/// The state is `null` while loading or when the status cannot be read: the
/// banner stays hidden, as the conflicts are informational.
@riverpod
class AgentsMigrationController extends _$AgentsMigrationController {
  @override
  Future<AgentsMigrationStatus?> build() async {
    try {
      final result = await ref.read(getAgentsMigrationStatusUseCaseProvider)();
      return result.valueOrNull;
    } on Object {
      return null;
    }
  }

  /// Dismisses the conflicts through the backend; the banner stays visible
  /// when the call fails.
  Future<void> dismiss() async {
    final result = await ref.read(dismissAgentsMigrationUseCaseProvider)();
    if (!ref.mounted) return;
    if (result case Success<AgentsMigrationStatus>(:final value)) {
      state = AsyncData<AgentsMigrationStatus?>(value);
    }
  }
}
