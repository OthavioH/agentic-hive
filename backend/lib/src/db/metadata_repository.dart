import 'package:agentic_hive_backend/src/db/app_database.dart';

/// Reads and writes installation facts (the `app_metadata` table).
abstract interface class MetadataRepository {
  /// The value stored under [key], or `null`.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value);
}

/// [MetadataRepository] backed by the drift [AppDatabase].
final class DriftMetadataRepository implements MetadataRepository {
  /// Creates a repository over [_db].
  new(this._db);

  final AppDatabase _db;

  @override
  Future<String?> read(String key) async {
    final query = _db.select(_db.appMetadata)
      ..where((row) => row.key.equals(key));
    return (await query.getSingleOrNull())?.value;
  }

  @override
  Future<void> write(String key, String value) => _db
      .into(_db.appMetadata)
      .insertOnConflictUpdate(
        AppMetadataCompanion.insert(key: key, value: value),
      );
}
