import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Creates a fresh temporary directory for the current test and deletes it,
/// recursively, when the test ends.
///
/// Register it before anything that holds a file inside it: tear-downs run in
/// reverse order, so resources registered later are released first. On
/// Windows the deletion fails if a database file in it is still open.
Directory createTestDir() {
  final dir = Directory.systemTemp.createTempSync('agentic_hive_persistence_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// The database file `hive.db` inside [dir] (not created).
File databaseFileIn(Directory dir) => File(p.join(dir.path, 'hive.db'));

/// Runs [sql] on a separate, raw connection to [file] and returns the rows.
///
/// The connection is not an `AppDatabase`: no migration, `onCreate` or
/// `beforeOpen` runs, and `PRAGMA user_version` is left as found. It is
/// closed before this returns. Throws a [StateError] if [file] does not exist,
/// so a probe never creates a database.
Future<List<Map<String, Object?>>> selectFromFile(
  File file,
  String sql, [
  List<Object?> args = const [],
]) async {
  if (!file.existsSync()) {
    throw StateError('No database file at ${file.path}.');
  }
  final user = _ReadOnlyUser();
  final executor = NativeDatabase(
    file,
    // Runs before drift compares versions, so the probe reports the version
    // already stored and drift never rewrites it.
    setup: (raw) => user.storedVersion = raw.userVersion,
  );
  try {
    await executor.ensureOpen(user);
    return await executor.runSelect(sql, args);
  } finally {
    await executor.close();
  }
}

/// `PRAGMA user_version` of [file], read through [selectFromFile].
Future<int> readUserVersion(File file) async {
  final rows = await selectFromFile(file, 'PRAGMA user_version');
  return rows.single['user_version']! as int;
}

/// Every `app_metadata` row of [file] as a key → value map.
Future<Map<String, String>> readMetadataRows(File file) async {
  final rows = await selectFromFile(
    file,
    'SELECT key, value FROM app_metadata ORDER BY key',
  );
  return {
    for (final row in rows) row['key']! as String: row['value']! as String,
  };
}

final class _ReadOnlyUser implements QueryExecutorUser {
  int storedVersion = 0;

  @override
  int get schemaVersion => storedVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
