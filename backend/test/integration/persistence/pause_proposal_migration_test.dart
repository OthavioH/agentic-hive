import 'package:agentic_hive_backend/src/data/pauses/drift_pause_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  test('migrates schemaVersion 8 to 9 adding proposal columns', () async {
    final dir = createTestDir();
    final dbFile = databaseFileIn(dir);

    final v8 = NativeDatabase(dbFile);
    await v8.ensureOpen(_V8SeedUser());
    await v8.runCustom('''
      CREATE TABLE workflows (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        definition TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await v8.runCustom('''
      CREATE TABLE runs (
        id TEXT NOT NULL PRIMARY KEY,
        workflow_id TEXT NOT NULL,
        workflow_name TEXT NOT NULL,
        workflow_definition TEXT NOT NULL,
        workspace_path TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        error_message TEXT,
        isolation_mode TEXT NOT NULL DEFAULT 'none',
        worktree_path TEXT,
        worktree_branch TEXT,
        input TEXT,
        workspace_id TEXT
      )
    ''');
    await v8.runCustom('''
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
        created_at TEXT NOT NULL,
        answered_at TEXT
      )
    ''');
    await v8.runCustom('''
      INSERT INTO runs (
        id, workflow_id, workflow_name, workflow_definition,
        workspace_path, status, started_at
      ) VALUES (
        'r1', 'wf-1', 'Flow', '{}', '/tmp/ws', 'paused',
        '2026-11-21T10:00:00.000Z'
      )
    ''');
    await v8.runCustom('''
      INSERT INTO pauses (
        id, run_id, node_id, kind, status, workflow_name, node_label,
        instructions, allow_feedback, options_json, created_at
      ) VALUES (
        'p-old', 'r1', 'gate', 'humanApproval', 'pending', 'Flow', 'Gate',
        'Review', 1, '[]', '2026-11-21T10:00:00.000Z'
      )
    ''');
    await v8.close();

    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    expect(db.schemaVersion, 13);

    final repo = DriftPauseRepository(db);
    addTearDown(repo.close);
    final oldPause = (await repo.getById('p-old')).valueOrNull!;
    expect(oldPause.proposal, isNull);
    expect(oldPause.proposalSchema, isNull);
    expect(oldPause.proposalSource, isNull);
    expect(oldPause.editedProposal, isNull);

    final created = await repo.create(
      Pause(
        id: 'p-new',
        runId: 'r1',
        nodeId: 'gate',
        kind: PauseKind.humanApproval,
        status: PauseStatus.pending,
        workflowName: 'Flow',
        nodeLabel: 'Gate',
        instructions: 'Review',
        proposal: const {'a': 1},
        proposalSchema: '{"type":"object"}',
        proposalSource: 'Planner',
        createdAt: DateTime.utc(2026, 11, 21),
      ),
    );
    expect(created.isSuccess, isTrue);
  });
}

final class _V8SeedUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 8;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
