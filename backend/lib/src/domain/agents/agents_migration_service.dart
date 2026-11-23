import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Tells the user which files of the global agents move could not be copied
/// (ADR 0025) and remembers that they dismissed the notice.
///
/// The conflicts are computed once at startup by the migration itself. A
/// dismissal is stored with the exact set of conflicts it applies to, so a
/// different set of conflicts after a later startup is reported again.
final class AgentsMigrationService {
  /// Creates the service for a migration from [legacyDir] into [targetDir]
  /// that left [conflicts] behind.
  const new({
    required this.legacyDir,
    required this.targetDir,
    required this.conflicts,
    required this._settings,
  });

  /// SQLite settings key holding the dismissed conflicts fingerprint.
  static const dismissedKey = 'agents.migration_dismissed';

  /// The folder the agents were moved from.
  final String legacyDir;

  /// The folder the agents were moved into.
  final String targetDir;

  /// Relative paths that exist in both folders with different content.
  final List<String> conflicts;

  final SettingsRepository _settings;

  String get _fingerprint => ([...conflicts]..sort()).join('\n');

  /// The current migration status.
  Future<Result<AgentsMigrationStatus>> status() async {
    final stored = await _settings.getAll();
    return stored.map(
      (values) => _build(
        dismissed: conflicts.isNotEmpty && values[dismissedKey] == _fingerprint,
      ),
    );
  }

  /// Marks the current conflicts as seen.
  Future<Result<AgentsMigrationStatus>> dismiss() async {
    final applied = await _settings.applyChanges({
      dismissedKey: conflicts.isEmpty ? null : _fingerprint,
    });
    return applied.map((_) => _build(dismissed: conflicts.isNotEmpty));
  }

  AgentsMigrationStatus _build({required bool dismissed}) =>
      AgentsMigrationStatus(
        legacyDir: legacyDir,
        targetDir: targetDir,
        conflicts: conflicts,
        dismissed: dismissed,
      );
}
