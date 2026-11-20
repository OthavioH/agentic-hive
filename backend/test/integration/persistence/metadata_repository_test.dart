import 'dart:io';

import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/db/metadata_repository.dart';
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  late File dbFile;
  late AppDatabase db;
  late MetadataRepository repository;

  setUp(() {
    dbFile = databaseFileIn(createTestDir());
    db = AppDatabase.open(dbFile);
    addTearDown(() => db.close());
    repository = DriftMetadataRepository(db);
  });

  test('read of a missing key returns null', () async {
    expect(await repository.read('missing'), isNull);

    await db.close();
    expect((await readMetadataRows(dbFile)).containsKey('missing'), isFalse);
  });

  test('write then read returns the value, stored as one row', () async {
    await repository.write('theme', 'dark');

    expect(await repository.read('theme'), 'dark');

    await db.close();
    final rows = await selectFromFile(
      dbFile,
      'SELECT value FROM app_metadata WHERE key = ?',
      ['theme'],
    );
    expect(rows, [
      {'value': 'dark'},
    ]);
  });

  test('writing a key twice keeps one row with the last value', () async {
    await repository.write('theme', 'dark');
    await repository.write('theme', 'light');

    expect(await repository.read('theme'), 'light');

    await db.close();
    final rows = await selectFromFile(
      dbFile,
      'SELECT value FROM app_metadata WHERE key = ?',
      ['theme'],
    );
    expect(rows, [
      {'value': 'light'},
    ]);
  });

  test('values survive closing and reopening the database', () async {
    await repository.write('theme', 'dark');
    await repository.write('locale', 'en');
    await db.close();

    // Restart: a new AppDatabase and repository on the same file.
    final reopened = AppDatabase.open(dbFile);
    addTearDown(reopened.close);
    final reopenedRepository = DriftMetadataRepository(reopened);

    expect(await reopenedRepository.read('theme'), 'dark');
    expect(await reopenedRepository.read('locale'), 'en');

    await reopened.close();
    final rows = await readMetadataRows(dbFile);
    expect(rows, containsPair('theme', 'dark'));
    expect(rows, containsPair('locale', 'en'));
    expect(rows.keys, contains(AppDatabase.installedAtKey));
    expect(rows, hasLength(3));
  });
}
