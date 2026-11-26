import 'package:agentic_hive_backend/src/data/pauses/drift_pause_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Build Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'human_approval',
        label: 'Approve',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 9),
    updatedAt: DateTime.utc(2026, 11, 20, 9),
  );

  test('migrates schemaVersion 10 to 11 adding pauses.parent_run_id', () async {
    final dir = createTestDir();
    final dbFile = databaseFileIn(dir);

    final v10 = NativeDatabase(dbFile);
    await v10.ensureOpen(_V10SeedUser());
    await v10.runCustom('''
        CREATE TABLE runs (
          id TEXT NOT NULL PRIMARY KEY,
          workflow_id TEXT,
          workflow_name TEXT NOT NULL,
          workflow_definition_json TEXT NOT NULL,
          workspace_path TEXT NOT NULL,
          workspace_id TEXT,
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
    await v10.runCustom('''
        INSERT INTO runs (
          id, workflow_id, workflow_name, workflow_definition_json,
          workspace_path, status, started_at
        ) VALUES (
          'r-1', 'wf-1', 'Flow', '{"id":"wf-1","name":"Flow","nodes":[],"edges":[],"entryNodeId":"n1","createdAt":"2026-11-20T09:00:00.000Z","updatedAt":"2026-11-20T09:00:00.000Z"}',
          '/tmp/ws', 'paused', '2026-11-21T10:00:00.000Z'
        )
      ''');
    await v10.runCustom('''
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
    await v10.runCustom('''
        INSERT INTO pauses (
          id, run_id, node_id, kind, status, workflow_name, node_label,
          options_json, created_at
        ) VALUES (
          'p-old', 'r-1', 'n1', 'humanApproval', 'pending', 'Flow', 'Approve',
          '[]', '2026-11-21T10:00:00.000Z'
        )
      ''');
    await v10.close();

    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    final tableInfo = await db.customSelect('PRAGMA table_info(pauses)').get();
    expect(await readUserVersion(dbFile), 12);
    final columnNames = tableInfo
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(columnNames, contains('parent_run_id'));

    final repo = DriftPauseRepository(db);
    final oldPause = (await repo.getById('p-old')).valueOrNull!;
    expect(oldPause.parentRunId, isNull);
  });

  test('round-trips Pause.parentRunId', () async {
    final dir = createTestDir();
    final db = AppDatabase.open(databaseFileIn(dir));
    addTearDown(db.close);

    final runRepo = DriftRunRepository(db);
    await runRepo.create(
      Run(
        id: 'child-1',
        workflowId: sampleWorkflow.id,
        workflowName: sampleWorkflow.name,
        workflowDefinition: sampleWorkflow,
        workspaceRoot: dir.path,
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 21, 10),
        parentRunId: 'parent-1',
      ),
    );

    final pauseRepo = DriftPauseRepository(db);
    final pause = Pause(
      id: 'p-1',
      runId: 'child-1',
      nodeId: 'n1',
      kind: PauseKind.humanApproval,
      status: PauseStatus.pending,
      workflowName: sampleWorkflow.name,
      nodeLabel: 'Approve',
      createdAt: DateTime.utc(2026, 11, 21, 10, 1),
      parentRunId: 'parent-1',
    );
    expect((await pauseRepo.create(pause)).isSuccess, isTrue);

    final fetched = (await pauseRepo.getById('p-1')).valueOrNull!;
    expect(fetched, pause);
    expect(fetched.parentRunId, 'parent-1');

    final listed = (await pauseRepo.list()).valueOrNull!;
    expect(listed.items.single.parentRunId, 'parent-1');
  });
}

final class _V10SeedUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 10;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
