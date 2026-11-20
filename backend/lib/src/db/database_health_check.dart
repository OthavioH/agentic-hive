import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

/// Checks that the database answers queries.
abstract interface class DatabaseHealthCheck {
  /// Runs the check; never throws.
  Future<DatabaseStatus> check();
}

/// [DatabaseHealthCheck] that queries the drift [AppDatabase].
final class DriftDatabaseHealthCheck implements DatabaseHealthCheck {
  /// Creates a check against [_db].
  new(this._db);

  static final _log = Logger('db.health');

  final AppDatabase _db;

  @override
  Future<DatabaseStatus> check() async {
    try {
      await _db.customSelect('SELECT 1').getSingle();
      final row = await _db.customSelect('PRAGMA user_version').getSingle();
      return DatabaseStatus(
        ok: true,
        schemaVersion: row.read<int>('user_version'),
      );
    } on Object catch (error, stackTrace) {
      _log.severe('Database health check failed.', error, stackTrace);
      return const DatabaseStatus(ok: false, error: 'database_unavailable');
    }
  }
}
