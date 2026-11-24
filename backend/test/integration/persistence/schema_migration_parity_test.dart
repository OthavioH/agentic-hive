import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  test('upgraded v10 database has identical PRAGMA table_info to a fresh v11 '
      'database for every table', () async {
    final freshDir = createTestDir();
    final freshFile = databaseFileIn(freshDir);
    final freshDb = AppDatabase.open(freshFile);
    await freshDb.customSelect('SELECT 1').get();
    final freshTables = await _tableNames(freshDb);
    final freshColumnsByTable = {
      for (final table in freshTables)
        table: await _tableColumns(freshDb, table),
    };
    final freshVersion = freshDb.schemaVersion;
    await freshDb.close();

    final upgradedDir = createTestDir();
    final upgradedFile = databaseFileIn(upgradedDir);
    final v10 = NativeDatabase(upgradedFile);
    await v10.ensureOpen(_SeedUser(10));
    await _createV10Schema(v10);
    await v10.close();

    final upgradedDb = AppDatabase.open(upgradedFile);
    addTearDown(upgradedDb.close);
    await upgradedDb.customSelect('SELECT 1').get();

    expect(await readUserVersion(upgradedFile), freshVersion);

    final upgradedTables = await _tableNames(upgradedDb);
    expect(upgradedTables, unorderedEquals(freshTables));

    for (final table in freshTables) {
      final freshCols = freshColumnsByTable[table]!;
      final upgradedCols = await _tableColumns(upgradedDb, table);
      expect(
        upgradedCols,
        equals(freshCols),
        reason: 'Schema drift in table "$table"',
      );
    }
  });
}

Future<List<String>> _tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();
  return [for (final row in rows) row.read<String>('name')];
}

Future<List<(String name, String type, int notnull, int pk)>> _tableColumns(
  AppDatabase db,
  String table,
) async {
  final rows = await db.customSelect('PRAGMA table_info("$table")').get();
  final cols = [
    for (final row in rows)
      (
        row.read<String>('name'),
        row.read<String>('type'),
        row.read<int>('notnull'),
        row.read<int>('pk'),
      ),
  ];
  return cols..sort((a, b) => a.$1.compareTo(b.$1));
}

Future<void> _createV10Schema(NativeDatabase db) async {
  await db.runCustom('''
    CREATE TABLE app_metadata (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
  await db.runCustom('''
    CREATE TABLE workspaces (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      root_path TEXT NOT NULL,
      is_git INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.runCustom('''
    CREATE TABLE workflows (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      definition_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.runCustom('''
    CREATE TABLE runs (
      id TEXT NOT NULL PRIMARY KEY,
      workflow_id TEXT,
      workflow_name TEXT NOT NULL,
      workflow_definition_json TEXT NOT NULL,
      workspace_path TEXT NOT NULL,
      workspace_id TEXT REFERENCES workspaces(id) ON DELETE CASCADE,
      status TEXT NOT NULL,
      started_at TEXT NOT NULL,
      finished_at TEXT,
      error_message TEXT,
      isolation_mode TEXT NOT NULL DEFAULT 'direct',
      worktree_path TEXT,
      worktree_branch TEXT,
      input TEXT,
      parent_run_id TEXT,
      parent_node_id TEXT,
      child_index INTEGER,
      child_name TEXT
    )
  ''');
  await db.runCustom('''
    CREATE TABLE checkpoints (
      id TEXT NOT NULL PRIMARY KEY,
      run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
      sequence INTEGER NOT NULL,
      completed_node_id TEXT,
      pending_node_ids_json TEXT NOT NULL,
      attempts_by_edge_json TEXT NOT NULL,
      circuit_breaker_count INTEGER NOT NULL,
      node_outputs_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE (run_id, sequence)
    )
  ''');
  await db.runCustom('''
    CREATE TABLE run_events (
      id TEXT NOT NULL PRIMARY KEY,
      run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
      sequence INTEGER NOT NULL,
      type TEXT NOT NULL,
      node_id TEXT,
      edge_id TEXT,
      payload_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE (run_id, sequence)
    )
  ''');
  await db.runCustom('''
    CREATE TABLE snapshots (
      id TEXT NOT NULL PRIMARY KEY,
      run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
      node_id TEXT,
      commit_hash TEXT NOT NULL,
      kind TEXT NOT NULL,
      added_count INTEGER NOT NULL,
      modified_count INTEGER NOT NULL,
      deleted_count INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  await db.runCustom('''
    CREATE TABLE settings (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.runCustom('''
    CREATE TABLE pauses (
      id TEXT NOT NULL PRIMARY KEY,
      run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
      node_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      status TEXT NOT NULL,
      workflow_name TEXT NOT NULL,
      node_label TEXT NOT NULL,
      title TEXT,
      instructions TEXT,
      allow_feedback INTEGER NOT NULL DEFAULT 1,
      question TEXT,
      options_json TEXT NOT NULL,
      decision TEXT,
      feedback TEXT,
      answer TEXT,
      proposal_json TEXT,
      proposal_schema TEXT,
      proposal_source TEXT,
      edited_proposal_json TEXT,
      created_at TEXT NOT NULL,
      answered_at TEXT
    )
  ''');
}

final class _SeedUser implements QueryExecutorUser {
  new(this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
