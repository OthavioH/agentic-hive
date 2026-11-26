import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
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

  Run makeRun(
    String id, {
    required DateTime startedAt,
    String? parentRunId,
    String? parentNodeId,
    int? childIndex,
  }) => Run(
    id: id,
    workflowId: sampleWorkflow.id,
    workflowName: sampleWorkflow.name,
    workflowDefinition: sampleWorkflow,
    workspaceRoot: '/tmp/ws',
    status: RunStatus.succeeded,
    startedAt: startedAt,
    parentRunId: parentRunId,
    parentNodeId: parentNodeId,
    childIndex: childIndex,
  );

  test(
    'listChildren returns only children of the parent, oldest first',
    () async {
      final dir = createTestDir();
      final db = AppDatabase.open(databaseFileIn(dir));
      addTearDown(db.close);

      final repo = DriftRunRepository(db);
      await repo.create(makeRun('p', startedAt: DateTime.utc(2026, 11, 21, 9)));
      await repo.create(
        makeRun('unrelated', startedAt: DateTime.utc(2026, 11, 21, 9, 1)),
      );
      await repo.create(
        makeRun(
          'c2',
          parentRunId: 'p',
          parentNodeId: 'fan',
          childIndex: 1,
          startedAt: DateTime.utc(2026, 11, 21, 9, 3),
        ),
      );
      await repo.create(
        makeRun(
          'c1',
          parentRunId: 'p',
          parentNodeId: 'fan',
          childIndex: 0,
          startedAt: DateTime.utc(2026, 11, 21, 9, 2),
        ),
      );
      await repo.create(
        makeRun(
          'c3',
          parentRunId: 'p',
          parentNodeId: 'other',
          childIndex: 0,
          startedAt: DateTime.utc(2026, 11, 21, 9, 4),
        ),
      );

      final allChildren = (await repo.listChildren('p')).valueOrNull!;
      expect(allChildren.map((r) => r.id), ['c1', 'c2', 'c3']);

      final fanChildren = (await repo.listChildren(
        'p',
        parentNodeId: 'fan',
      )).valueOrNull!;
      expect(fanChildren.map((r) => r.id), ['c1', 'c2']);
    },
  );

  test('listChildren is empty for an unknown parent', () async {
    final dir = createTestDir();
    final db = AppDatabase.open(databaseFileIn(dir));
    addTearDown(db.close);

    final repo = DriftRunRepository(db);
    final result = (await repo.listChildren('missing')).valueOrNull!;
    expect(result, isEmpty);
  });
}
