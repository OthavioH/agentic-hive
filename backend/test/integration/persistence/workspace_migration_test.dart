import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/data/workflows/drift_workflow_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_workspace_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUp(() {
    dir = createTestDir();
    dbFile = databaseFileIn(dir);
  });

  final workflow = Workflow(
    id: 'wf-1',
    name: 'Release Flow',
    description: 'desc',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Step',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 10),
    updatedAt: DateTime.utc(2026, 11, 20, 10),
  );
  final workflowJson = jsonEncode(workflow.toJson());

  /// Seeds a database as shipped at [version] (6, or 7 with `runs.input`).
  Future<void> seedLegacy({
    required List<({String id, String path, String status})> runs,
    int version = 6,
  }) async {
    final executor = NativeDatabase(dbFile);
    await executor.ensureOpen(_SeedUser(version));
    final statements = <List<String>>[
      [
        'CREATE TABLE app_metadata (key TEXT NOT NULL PRIMARY KEY, ',
        'value TEXT NOT NULL) ',
      ],
      [
        'CREATE TABLE workflows (id TEXT NOT NULL PRIMARY KEY, ',
        'name TEXT NOT NULL, description TEXT, ',
        'definition_json TEXT NOT NULL, created_at TEXT NOT NULL, ',
        'updated_at TEXT NOT NULL) ',
      ],
      [
        'CREATE TABLE runs (id TEXT NOT NULL PRIMARY KEY, workflow_id TEXT, ',
        'workflow_name TEXT NOT NULL, workflow_definition_json TEXT NOT NULL, ',
        'workspace_path TEXT NOT NULL, status TEXT NOT NULL, ',
        'started_at TEXT NOT NULL, finished_at TEXT, error_message TEXT, ',
        "isolation_mode TEXT NOT NULL DEFAULT 'direct', ",
        'worktree_path TEXT, worktree_branch TEXT',
        if (version >= 7) ', input TEXT',
        ') ',
      ],
      [
        'CREATE TABLE checkpoints (id TEXT NOT NULL PRIMARY KEY, ',
        'run_id TEXT NOT NULL REFERENCES runs (id) ON DELETE CASCADE, ',
        'sequence INTEGER NOT NULL, completed_node_id TEXT, ',
        'pending_node_ids_json TEXT NOT NULL, ',
        'attempts_by_edge_json TEXT NOT NULL, ',
        'circuit_breaker_count INTEGER NOT NULL, ',
        'node_outputs_json TEXT NOT NULL, ',
        'created_at TEXT NOT NULL) ',
      ],
      [
        'CREATE TABLE run_events (id TEXT NOT NULL PRIMARY KEY, ',
        'run_id TEXT NOT NULL REFERENCES runs (id) ON DELETE CASCADE, ',
        'sequence INTEGER NOT NULL, type TEXT NOT NULL, ',
        'node_id TEXT, edge_id TEXT, ',
        'payload_json TEXT NOT NULL, created_at TEXT NOT NULL) ',
      ],
      [
        'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, ',
        'value TEXT NOT NULL, updated_at TEXT NOT NULL) ',
      ],
      [
        'CREATE TABLE snapshots (id TEXT NOT NULL PRIMARY KEY, ',
        'run_id TEXT NOT NULL REFERENCES runs (id) ON DELETE CASCADE, ',
        'node_id TEXT, commit_hash TEXT NOT NULL, kind TEXT NOT NULL, ',
        'added_count INTEGER NOT NULL, modified_count INTEGER NOT NULL, ',
        'deleted_count INTEGER NOT NULL, created_at TEXT NOT NULL) ',
      ],
      [
        'CREATE TABLE pauses (id TEXT NOT NULL PRIMARY KEY, ',
        'run_id TEXT NOT NULL REFERENCES runs (id) ON DELETE CASCADE, ',
        'node_id TEXT NOT NULL, kind TEXT NOT NULL, status TEXT NOT NULL, ',
        'workflow_name TEXT NOT NULL, node_label TEXT NOT NULL, ',
        'title TEXT, instructions TEXT, ',
        'allow_feedback INTEGER NOT NULL DEFAULT 1, question TEXT, ',
        'options_json TEXT NOT NULL, decision TEXT, feedback TEXT, ',
        'answer TEXT, created_at TEXT NOT NULL, answered_at TEXT) ',
      ],
    ];
    for (final parts in statements) {
      await executor.runCustom(parts.join());
    }
    await executor.runInsert(
      'INSERT INTO workflows VALUES (?, ?, ?, ?, ?, ?)',
      [
        'wf-1',
        'Release Flow',
        'desc',
        jsonEncode({
          'nodes': workflow.nodes.map((n) => n.toJson()).toList(),
          'edges': <Object?>[],
          'entryNodeId': 'n1',
          'schemaVersion': 1,
        }),
        '2026-11-20T10:00:00.000Z',
        '2026-11-20T10:00:00.000Z',
      ],
    );
    for (final run in runs) {
      await executor.runInsert(
        'INSERT INTO runs (id, workflow_id, workflow_name, '
        'workflow_definition_json, workspace_path, status, started_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          run.id,
          'wf-1',
          'Release Flow',
          workflowJson,
          run.path,
          run.status,
          '2026-11-21T10:00:00.000Z',
        ],
      );
    }
    await executor.runCustom('PRAGMA user_version = $version');
    await executor.close();
  }

  test('schemaVersion is 8', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    expect(db.schemaVersion, 11);
  });

  test('migrating 6 to 8 attaches every run to a workspace named after its '
      'folder and keeps workflows and runs', () async {
    final projectA = p.join(dir.path, 'project-a');
    final projectB = p.join(dir.path, 'project-b');
    Directory(p.join(projectA, '.git')).createSync(recursive: true);
    Directory(projectB).createSync(recursive: true);
    await seedLegacy(
      runs: [
        (id: 'r1', path: projectA, status: 'succeeded'),
        (id: 'r2', path: '$projectA${p.separator}', status: 'failed'),
        (id: 'r3', path: projectB, status: 'running'),
        (id: 'r4', path: p.join(dir.path, 'gone'), status: 'cancelled'),
      ],
    );

    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    final workspaces = (await DriftWorkspaceRepository(db).list()).valueOrNull!;
    expect(workspaces.map((w) => w.name).toSet(), {
      'project-a',
      'project-b',
      'gone',
    });
    expect(workspaces, hasLength(3));
    final a = workspaces.singleWhere((w) => w.name == 'project-a');
    expect(a.isGit, isTrue);
    expect(a.rootPath, p.normalize(projectA));
    expect(workspaces.singleWhere((w) => w.name == 'project-b').isGit, isFalse);

    final runs = DriftRunRepository(db);
    final r1 = (await runs.getById('r1')).valueOrNull!;
    final r2 = (await runs.getById('r2')).valueOrNull!;
    final r3 = (await runs.getById('r3')).valueOrNull!;
    final r4 = (await runs.getById('r4')).valueOrNull!;
    expect(r1.workspaceId, a.id);
    expect(r2.workspaceId, a.id);
    expect(r3.workspaceId, isNotNull);
    expect(r3.workspaceId, isNot(a.id));
    expect(r4.workspaceId, isNotNull);
    expect(r1.status, RunStatus.succeeded);
    expect(r3.status, RunStatus.running);
    expect(r1.workspacePath, projectA);

    final workflow = (await DriftWorkflowRepository(db).getById('wf-1'))
        .valueOrNull!;
    expect(workflow.name, 'Release Flow');
    expect(await readUserVersionOf(db), 10);
  });

  test('migrating 6 to 8 with no runs creates no workspaces', () async {
    await seedLegacy(runs: const []);

    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    expect((await DriftWorkspaceRepository(db).list()).valueOrNull, isEmpty);
  });

  test('migrating 6 to 8 creates the unique root-path index', () async {
    await seedLegacy(runs: const []);

    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND tbl_name='workspaces'",
        )
        .get();
    expect(
      rows.map((r) => r.read<String>('name')),
      contains('idx_workspaces_root_path'),
    );
  });

  test(
    'migrating 7 to 8 keeps run input and attaches runs to workspaces',
    () async {
      final project = p.join(dir.path, 'project-c');
      Directory(project).createSync(recursive: true);
      await seedLegacy(
        version: 7,
        runs: [(id: 'r1', path: project, status: 'succeeded')],
      );
      final raw = NativeDatabase(dbFile);
      await raw.ensureOpen(_SeedUser(7));
      await raw.runUpdate('UPDATE runs SET input = ? WHERE id = ?', [
        'Audit all handlers',
        'r1',
      ]);
      await raw.close();

      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);

      final run = (await DriftRunRepository(db).getById('r1')).valueOrNull!;
      expect(run.input, 'Audit all handlers');
      expect(run.workspaceId, isNotNull);
      final workspaces = (await DriftWorkspaceRepository(
        db,
      ).list()).valueOrNull!;
      expect(workspaces.single.name, 'project-c');
      expect(await readUserVersionOf(db), 10);
    },
  );
}

Future<int> readUserVersionOf(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
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
