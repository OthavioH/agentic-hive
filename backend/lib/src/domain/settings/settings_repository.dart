import 'package:agentic_hive_backend/src/core/result.dart';

/// Persistence boundary for runtime application settings in SQLite.
abstract interface class SettingsRepository {
  /// Reads all persisted key/value setting pairs.
  Future<Result<Map<String, String>>> getAll();

  /// Atomically applies [changes] in a single transaction.
  ///
  /// Non-null values are upserted; `null` values delete the corresponding key.
  Future<Result<void>> applyChanges(Map<String, String?> changes);
}
