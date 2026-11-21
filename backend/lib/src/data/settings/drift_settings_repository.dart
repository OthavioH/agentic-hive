import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_repository.dart';

/// Drift/SQLite implementation of [SettingsRepository].
final class DriftSettingsRepository implements SettingsRepository {
  /// Creates a repository backed by [_db].
  new(this._db, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<Result<Map<String, String>>> getAll() async {
    try {
      final rows = await _db.select(_db.settings).get();
      return Success({for (final row in rows) row.key: row.value});
    } on Object catch (e) {
      return FailureResult(
        PersistenceFailure('Failed to read runtime settings.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> applyChanges(Map<String, String?> changes) async {
    if (changes.isEmpty) return const Success<void>(null);
    try {
      final timestamp = _now().toUtc().toIso8601String();
      await _db.transaction(() async {
        for (final entry in changes.entries) {
          final value = entry.value;
          if (value == null) {
            await (_db.delete(
              _db.settings,
            )..where((row) => row.key.equals(entry.key))).go();
          } else {
            await _db
                .into(_db.settings)
                .insertOnConflictUpdate(
                  SettingsCompanion.insert(
                    key: entry.key,
                    value: value,
                    updatedAt: timestamp,
                  ),
                );
          }
        }
      });
      return const Success<void>(null);
    } on Object catch (e) {
      return FailureResult(
        PersistenceFailure('Failed to save runtime settings.', cause: e),
      );
    }
  }
}
