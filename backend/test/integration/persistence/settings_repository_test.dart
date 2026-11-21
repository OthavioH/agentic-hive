import 'dart:io';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/settings/drift_settings_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  late File dbFile;

  setUp(() {
    dbFile = databaseFileIn(createTestDir());
  });

  group('schema v2 -> v6 migration', () {
    test('creates settings table and preserves existing v2 data', () async {
      // Create a v2-shaped SQLite database directly without AppDatabase.
      final raw = NativeDatabase(dbFile);
      await raw.ensureOpen(_V2SeedUser());
      await raw.runCustom(
        'CREATE TABLE app_metadata (key TEXT NOT NULL PRIMARY KEY, '
        'value TEXT NOT NULL)',
      );
      await raw.runCustom(
        'CREATE TABLE workflows (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, description TEXT, definition_json TEXT NOT NULL, '
        'created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
      );
      await raw.runCustom(
        "INSERT INTO app_metadata (key, value) VALUES ('installed_at', "
        "'2026-11-20T00:00:00.000Z')",
      );
      await raw.runCustom('PRAGMA user_version = 2');
      await raw.close();

      // Open with AppDatabase (schemaVersion 6) -> runs onUpgrade(2 -> 6).
      final db = AppDatabase.open(dbFile);
      try {
        await db.customSelect('SELECT 1').get();
      } finally {
        await db.close();
      }

      expect(await readUserVersion(dbFile), 6);
      final metadata = await readMetadataRows(dbFile);
      expect(metadata['installed_at'], '2026-11-20T00:00:00.000Z');

      final tables = await selectFromFile(
        dbFile,
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'settings'",
      );
      expect(tables, hasLength(1));

      final columns = await selectFromFile(
        dbFile,
        'PRAGMA table_info(settings)',
      );
      final byName = {for (final c in columns) c['name']! as String: c};
      expect(byName.keys, unorderedEquals(['key', 'value', 'updated_at']));
      expect(byName['key']!['pk'], 1);
    });
  });

  group('DriftSettingsRepository', () {
    late AppDatabase db;
    late DriftSettingsRepository repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      repository = DriftSettingsRepository(
        db,
        now: () => DateTime.utc(2026, 11, 21, 12),
      );
      addTearDown(db.close);
    });

    test('returns empty map when no settings are stored', () async {
      final result = await repository.getAll();
      expect(result, isA<Success<Map<String, String>>>());
      expect((result as Success<Map<String, String>>).value, isEmpty);
    });

    test('upserts and deletes keys atomically in applyChanges', () async {
      await repository.applyChanges({
        'agents_dir': '/custom/agents',
        'default_workspace_dir': '/work',
        'harness_override.claude_code': '/usr/bin/claude',
      });

      var loaded =
          (await repository.getAll() as Success<Map<String, String>>).value;
      expect(loaded, {
        'agents_dir': '/custom/agents',
        'default_workspace_dir': '/work',
        'harness_override.claude_code': '/usr/bin/claude',
      });

      await repository.applyChanges({
        'agents_dir': null,
        'default_workspace_dir': '/new-work',
        'harness_override.claude_code': null,
      });

      loaded =
          (await repository.getAll() as Success<Map<String, String>>).value;
      expect(loaded, {'default_workspace_dir': '/new-work'});
    });
  });
}

final class _V2SeedUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
