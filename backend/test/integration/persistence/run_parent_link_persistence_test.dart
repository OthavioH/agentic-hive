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
        type: 'command',
        label: 'Run',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 9),
    updatedAt: DateTime.utc(2026, 11, 20, 9),
  );

  test(
    'migrates schemaVersion 9 to 10 adding the parent link columns',
    () async {
      final dir = createTestDir();
      final dbFile = databaseFileIn(dir);

      final v9 = NativeDatabase(dbFile);
      await v9.ensureOpen(_V9SeedUser());
      await v9.runCustom('''
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
          input TEXT
        )
      ''');
      await v9.runCustom('''
        INSERT INTO runs (
          id, workflow_id, workflow_name, workflow_definition_json,
          workspace_path, status, started_at
        ) VALUES (
          'r-old', 'wf-1', 'Flow', '{"id":"wf-1","name":"Flow","nodes":[],"edges":[],"entryNodeId":"n1","createdAt":"2026-11-20T09:00:00.000Z","updatedAt":"2026-11-20T09:00:00.000Z"}',
          '/tmp/ws', 'succeeded', '2026-11-21T10:00:00.000Z'
        )
      ''');
      await v9.close();

      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);

      final repo = DriftRunRepository(db);
      final oldRun = (await repo.getById('r-old')).valueOrNull!;
      expect(await readUserVersion(dbFile), 11);
      expect(oldRun.parentRunId, isNull);
      expect(oldRun.parentNodeId, isNull);
      expect(oldRun.childIndex, isNull);
      expect(oldRun.childName, isNull);

      final tableInfo = await db.customSelect('PRAGMA table_info(runs)').get();
      final columnNames = tableInfo
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(
        columnNames,
        containsAll([
          'parent_run_id',
          'parent_node_id',
          'child_index',
          'child_name',
        ]),
      );
    },
  );

  test(
    'round-trips parentRunId, parentNodeId, childIndex and childName',
    () async {
      final db = AppDatabase.open(databaseFileIn(createTestDir()));
      addTearDown(db.close);
      final repo = DriftRunRepository(db);

      final child = Run(
        id: 'child-1',
        workflowId: 'wf-1',
        workflowName: 'Build Flow',
        workflowDefinition: sampleWorkflow,
        workspacePath: '/tmp/ws',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 21, 10),
        parentRunId: 'parent-1',
        parentNodeId: 'fan-1',
        childIndex: 2,
        childName: 'Fix bug #3',
      );
      expect((await repo.create(child)).isSuccess, isTrue);

      final fetched = (await repo.getById('child-1')).valueOrNull!;
      expect(fetched, child);

      final byStatus = (await repo.listByStatus(RunStatus.running))
          .valueOrNull!;
      expect(byStatus.single, child);
    },
  );

  test('list summaries carry parentRunId and parentNodeId', () async {
    final db = AppDatabase.open(databaseFileIn(createTestDir()));
    addTearDown(db.close);
    final repo = DriftRunRepository(db);

    final child = Run(
      id: 'child-2',
      workflowId: 'wf-1',
      workflowName: 'Build Flow',
      workflowDefinition: sampleWorkflow,
      workspacePath: '/tmp/ws',
      status: RunStatus.succeeded,
      startedAt: DateTime.utc(2026, 11, 21, 10),
      parentRunId: 'parent-9',
      parentNodeId: 'fan-2',
      childIndex: 0,
      childName: 'Item 1',
    );
    expect((await repo.create(child)).isSuccess, isTrue);

    final listed = (await repo.list()).valueOrNull!;
    expect(listed.items.single.parentRunId, 'parent-9');
    expect(listed.items.single.parentNodeId, 'fan-2');
  });
}

final class _V9SeedUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 9;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
