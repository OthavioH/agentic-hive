import 'dart:io';

import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  late File dbFile;

  setUp(() {
    dbFile = databaseFileIn(createTestDir());
  });

  /// Opens [file] as a new [AppDatabase], runs one query so drift actually
  /// opens it (and migrates), then closes it.
  Future<void> openAndClose(File file) async {
    final db = AppDatabase.open(file);
    try {
      await db.customSelect('SELECT 1').get();
    } finally {
      await db.close();
    }
  }

  group('first open', () {
    test('creates the app_metadata table with its columns', () async {
      await openAndClose(dbFile);

      final tables = await selectFromFile(
        dbFile,
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'app_metadata'",
      );
      expect(tables, hasLength(1));

      final columns = await selectFromFile(
        dbFile,
        'PRAGMA table_info(app_metadata)',
      );
      final byName = {for (final c in columns) c['name']! as String: c};
      expect(byName.keys, unorderedEquals(['key', 'value']));
      expect(byName['key']!['type'], 'TEXT');
      expect(byName['key']!['pk'], 1);
      expect(byName['value']!['type'], 'TEXT');
      expect(byName['value']!['notnull'], 1);
    });

    test('stores the schema version in PRAGMA user_version', () async {
      final db = AppDatabase.open(dbFile);
      final expectedVersion = db.schemaVersion;
      await db.customSelect('SELECT 1').get();
      await db.close();

      expect(expectedVersion, 9);
      expect(await readUserVersion(dbFile), expectedVersion);
    });

    test('writes installed_at as the current UTC time in ISO-8601', () async {
      final before = DateTime.now().toUtc();
      await openAndClose(dbFile);
      final after = DateTime.now().toUtc();

      final rows = await readMetadataRows(dbFile);
      expect(rows.keys, [AppDatabase.installedAtKey]);

      final raw = rows[AppDatabase.installedAtKey]!;
      final installedAt = DateTime.parse(raw);
      expect(raw, endsWith('Z'), reason: 'UTC ISO-8601 ends with Z');
      expect(installedAt.isUtc, isTrue);
      expect(installedAt.toIso8601String(), raw);
      expect(installedAt.isBefore(before), isFalse);
      expect(installedAt.isAfter(after), isFalse);
    });
  });

  group('reopen (restart)', () {
    test('keeps installed_at and does not run onCreate again', () async {
      await openAndClose(dbFile);
      final firstRows = await readMetadataRows(dbFile);

      // Restart: a brand-new AppDatabase on the same file.
      await openAndClose(dbFile);

      final secondRows = await readMetadataRows(dbFile);
      expect(secondRows, firstRows);
      expect(secondRows, hasLength(1));
      expect(await readUserVersion(dbFile), 9);
    });
  });

  group('beforeOpen', () {
    test('turns PRAGMA foreign_keys on for the open connection', () async {
      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);

      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.read<int>('foreign_keys'), 1);

      // A raw connection that skips beforeOpen sees SQLite's default (off),
      // so the value above comes from beforeOpen, not from the file.
      final raw = await selectFromFile(dbFile, 'PRAGMA foreign_keys');
      expect(raw.single['foreign_keys'], 0);
    });
  });
}
