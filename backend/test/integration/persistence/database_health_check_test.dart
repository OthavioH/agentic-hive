import 'dart:io';

import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/db/database_health_check.dart';
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  late File dbFile;
  late AppDatabase db;
  late DatabaseHealthCheck healthCheck;

  setUp(() {
    dbFile = databaseFileIn(createTestDir());
    db = AppDatabase.open(dbFile);
    addTearDown(() => db.close());
    healthCheck = DriftDatabaseHealthCheck(db);
  });

  test('reports ok with the schema version on an open database', () async {
    final status = await healthCheck.check();

    expect(status.ok, isTrue);
    expect(status.schemaVersion, 10);
    expect(status.error, isNull);
    expect(await readUserVersion(dbFile), status.schemaVersion);
  });

  test('reports database_unavailable without throwing once the database is '
      'closed', () async {
    await healthCheck.check();
    await db.close();

    // A throw here fails the test: check() must turn errors into a status.
    final status = await healthCheck.check();

    expect(status.ok, isFalse);
    expect(status.error, 'database_unavailable');
    expect(status.schemaVersion, isNull);
  });
}
