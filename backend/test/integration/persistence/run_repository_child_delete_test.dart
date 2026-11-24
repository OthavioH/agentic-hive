import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_workspace_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  late File dbFile;

  setUp(() {
    dbFile = databaseFileIn(createTestDir());
  });

  final sampleWorkflow = Workflow(
    id: 'wf-parent',
    name: 'Parent Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Plan',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 9),
    updatedAt: DateTime.utc(2026, 11, 20, 9),
  );

  Run makeRun({
    required String id,
    required RunStatus status,
    required DateTime startedAt,
    String? workflowId = 'wf-parent',
    String? workspaceId,
    DateTime? finishedAt,
    String? parentRunId,
    String? parentNodeId,
    int? childIndex,
    String? childName,
  }) => Run(
    id: id,
    workflowId: workflowId,
    workflowName: sampleWorkflow.name,
    workflowDefinition: sampleWorkflow,
    workspaceId: workspaceId,
    workspacePath: '/tmp/ws',
    status: status,
    startedAt: startedAt,
    finishedAt: finishedAt,
    parentRunId: parentRunId,
    parentNodeId: parentNodeId,
    childIndex: childIndex,
    childName: childName,
  );

  test(
    'delete removes the children with the parent and returns children first, '
    'parent last',
    () async {
      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);
      final now = DateTime.utc(2026, 11, 20, 9);
      final workspaces = DriftWorkspaceRepository(db);
      for (final wsId in ['ws-1', 'ws-2']) {
        await workspaces.create(
          Workspace(
            id: wsId,
            name: wsId,
            rootPath: '/tmp/$wsId',
            isGit: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      final repo = DriftRunRepository(db);

      final t0 = DateTime.utc(2026, 11, 20, 10);
      await repo.create(
        makeRun(id: 'p', status: RunStatus.succeeded, startedAt: t0),
      );
      await repo.create(
        makeRun(
          id: 'c1',
          status: RunStatus.succeeded,
          startedAt: t0.add(const Duration(seconds: 1)),
          workflowId: 'wf-child',
          parentRunId: 'p',
          parentNodeId: 'fan-1',
          childIndex: 0,
        ),
      );
      await repo.create(
        makeRun(
          id: 'c2',
          status: RunStatus.failed,
          startedAt: t0.add(const Duration(seconds: 2)),
          workflowId: 'wf-child',
          parentRunId: 'p',
          parentNodeId: 'fan-1',
          childIndex: 1,
        ),
      );
      await repo.create(
        makeRun(
          id: 'other',
          status: RunStatus.succeeded,
          startedAt: t0.add(const Duration(seconds: 3)),
        ),
      );

      final res = await repo.delete('p');
      expect(res.valueOrNull, ['c1', 'c2', 'p']);
      expect((await repo.getById('p')).isFailure, isTrue);
      expect((await repo.getById('c1')).isFailure, isTrue);
      expect((await repo.getById('c2')).isFailure, isTrue);
      expect((await repo.getById('other')).isSuccess, isTrue);
    },
  );

  test('delete refuses when a child is active and deletes nothing', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final repo = DriftRunRepository(db);

    final t0 = DateTime.utc(2026, 11, 20, 10);
    await repo.create(
      makeRun(id: 'p', status: RunStatus.succeeded, startedAt: t0),
    );
    await repo.create(
      makeRun(
        id: 'c1',
        status: RunStatus.running,
        startedAt: t0.add(const Duration(seconds: 1)),
        workflowId: 'wf-child',
        parentRunId: 'p',
      ),
    );

    final res = await repo.delete('p');
    expect(res.failureOrNull, isA<ConflictFailure>());
    expect(res.failureOrNull!.message, contains('child run "c1"'));
    expect((await repo.getById('p')).isSuccess, isTrue);
    expect((await repo.getById('c1')).isSuccess, isTrue);
  });

  test('delete keeps the existing conflict for an active run', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final repo = DriftRunRepository(db);

    await repo.create(
      makeRun(
        id: 'p',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 10),
      ),
    );

    final res = await repo.delete('p');
    expect(res.failureOrNull, isA<ConflictFailure>());
    expect(
      res.failureOrNull!.message,
      'Cannot delete active run "p" with status "running".',
    );
  });

  test('delete treats a cancellationUncertain child as deletable', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final repo = DriftRunRepository(db);

    final t0 = DateTime.utc(2026, 11, 20, 10);
    await repo.create(
      makeRun(id: 'p', status: RunStatus.succeeded, startedAt: t0),
    );
    await repo.create(
      makeRun(
        id: 'c1',
        status: RunStatus.cancellationUncertain,
        startedAt: t0.add(const Duration(seconds: 1)),
        workflowId: 'wf-child',
        parentRunId: 'p',
      ),
    );

    final res = await repo.delete('p');
    expect(res.valueOrNull, ['c1', 'p']);
    expect((await repo.getById('c1')).isFailure, isTrue);
  });

  test('delete of a child leaves the parent', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final repo = DriftRunRepository(db);

    final t0 = DateTime.utc(2026, 11, 20, 10);
    await repo.create(
      makeRun(id: 'p', status: RunStatus.succeeded, startedAt: t0),
    );
    await repo.create(
      makeRun(
        id: 'c1',
        status: RunStatus.succeeded,
        startedAt: t0.add(const Duration(seconds: 1)),
        workflowId: 'wf-child',
        parentRunId: 'p',
      ),
    );

    final res = await repo.delete('c1');
    expect(res.valueOrNull, ['c1']);
    expect((await repo.getById('c1')).isFailure, isTrue);
    expect((await repo.getById('p')).isSuccess, isTrue);
  });

  test('delete of an unknown id is NotFound', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final repo = DriftRunRepository(db);

    final res = await repo.delete('missing');
    expect(res.failureOrNull, isA<NotFoundFailure>());
  });

  test('deleteAllOfWorkflow deletes the children of deleted parents', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final now = DateTime.utc(2026, 11, 20, 9);
    final workspaces = DriftWorkspaceRepository(db);
    for (final wsId in ['ws-1', 'ws-2']) {
      await workspaces.create(
        Workspace(
          id: wsId,
          name: wsId,
          rootPath: '/tmp/$wsId',
          isGit: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final repo = DriftRunRepository(db);

    final t0 = DateTime.utc(2026, 11, 20, 10);
    await repo.create(
      makeRun(id: 'p', status: RunStatus.succeeded, startedAt: t0),
    );
    await repo.create(
      makeRun(
        id: 'c1',
        status: RunStatus.succeeded,
        startedAt: t0.add(const Duration(seconds: 1)),
        workflowId: 'wf-child',
        parentRunId: 'p',
      ),
    );
    await repo.create(
      makeRun(
        id: 'c2',
        status: RunStatus.failed,
        startedAt: t0.add(const Duration(seconds: 2)),
        workflowId: 'wf-child',
        parentRunId: 'p',
      ),
    );

    final res = await repo.deleteAllOfWorkflow('wf-parent');
    expect(res.valueOrNull, ['p', 'c1', 'c2']);
    expect((await repo.getById('p')).isFailure, isTrue);
    expect((await repo.getById('c1')).isFailure, isTrue);
    expect((await repo.getById('c2')).isFailure, isTrue);
  });

  test('deleteAllOfWorkflow reports active children in the failure map, oldest '
      'first', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final now = DateTime.utc(2026, 11, 20, 9);
    final workspaces = DriftWorkspaceRepository(db);
    for (final wsId in ['ws-1', 'ws-2']) {
      await workspaces.create(
        Workspace(
          id: wsId,
          name: wsId,
          rootPath: '/tmp/$wsId',
          isGit: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final repo = DriftRunRepository(db);

    final t0 = DateTime.utc(2026, 11, 20, 10);
    await repo.create(
      makeRun(id: 'p', status: RunStatus.succeeded, startedAt: t0),
    );
    await repo.create(
      makeRun(
        id: 'c1',
        status: RunStatus.running,
        startedAt: t0.add(const Duration(seconds: 1)),
        workflowId: 'wf-child',
        parentRunId: 'p',
      ),
    );

    final res = await repo.deleteAllOfWorkflow('wf-parent');
    final failure = res.failureOrNull! as WorkflowHasActiveRunsFailure;
    expect(failure.activeRuns.keys, ['c1']);
    expect((await repo.getById('p')).isSuccess, isTrue);
    expect((await repo.getById('c1')).isSuccess, isTrue);
  });

  test(
    'deleteAllOfWorkflow with an orphan parent keeps its children',
    () async {
      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);
      final now = DateTime.utc(2026, 11, 20, 9);
      final workspaces = DriftWorkspaceRepository(db);
      for (final wsId in ['ws-1', 'ws-2']) {
        await workspaces.create(
          Workspace(
            id: wsId,
            name: wsId,
            rootPath: '/tmp/$wsId',
            isGit: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      final repo = DriftRunRepository(db);

      final t0 = DateTime.utc(2026, 11, 20, 10);
      await repo.create(
        makeRun(
          id: 'p',
          status: RunStatus.cancellationUncertain,
          startedAt: t0,
        ),
      );
      await repo.create(
        makeRun(
          id: 'c1',
          status: RunStatus.succeeded,
          startedAt: t0.add(const Duration(seconds: 1)),
          workflowId: 'wf-child',
          parentRunId: 'p',
        ),
      );

      final res = await repo.deleteAllOfWorkflow('wf-parent', orphanIds: {'p'});
      expect(res.valueOrNull, isEmpty);
      expect((await repo.getById('p')).valueOrNull?.workflowId, isNull);
      final child = (await repo.getById('c1')).valueOrNull!;
      expect(child.workflowId, 'wf-child');
      expect(child.parentRunId, 'p');
    },
  );

  test('deleteAllOfWorkflow with an orphan child keeps it with workflowId, '
      'parentRunId and parentNodeId cleared', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final now = DateTime.utc(2026, 11, 20, 9);
    final workspaces = DriftWorkspaceRepository(db);
    for (final wsId in ['ws-1', 'ws-2']) {
      await workspaces.create(
        Workspace(
          id: wsId,
          name: wsId,
          rootPath: '/tmp/$wsId',
          isGit: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final repo = DriftRunRepository(db);

    final t0 = DateTime.utc(2026, 11, 20, 10);
    await repo.create(
      makeRun(id: 'p', status: RunStatus.succeeded, startedAt: t0),
    );
    await repo.create(
      makeRun(
        id: 'c1',
        status: RunStatus.cancellationUncertain,
        startedAt: t0.add(const Duration(seconds: 1)),
        workflowId: 'wf-child',
        parentRunId: 'p',
        parentNodeId: 'fan-1',
        childIndex: 2,
        childName: 'item-2',
      ),
    );

    final res = await repo.deleteAllOfWorkflow('wf-parent', orphanIds: {'c1'});
    expect(res.valueOrNull, ['p']);
    expect((await repo.getById('p')).isFailure, isTrue);
    final child = (await repo.getById('c1')).valueOrNull!;
    expect(child.workflowId, isNull);
    expect(child.parentRunId, isNull);
    expect(child.parentNodeId, isNull);
    expect(child.childIndex, 2);
    expect(child.childName, 'item-2');
  });

  test('deleteAllOfWorkflow does not delete children of other parents and '
      'respects workspaceId scope', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    final now = DateTime.utc(2026, 11, 20, 9);
    final workspaces = DriftWorkspaceRepository(db);
    for (final wsId in ['ws-1', 'ws-2']) {
      await workspaces.create(
        Workspace(
          id: wsId,
          name: wsId,
          rootPath: '/tmp/$wsId',
          isGit: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final repo = DriftRunRepository(db);

    final t0 = DateTime.utc(2026, 11, 20, 10);
    await repo.create(
      makeRun(
        id: 'p-ws1',
        status: RunStatus.succeeded,
        startedAt: t0,
        workspaceId: 'ws-1',
      ),
    );
    await repo.create(
      makeRun(
        id: 'c-ws1',
        status: RunStatus.succeeded,
        startedAt: t0.add(const Duration(seconds: 1)),
        workflowId: 'wf-child',
        workspaceId: 'ws-1',
        parentRunId: 'p-ws1',
      ),
    );
    await repo.create(
      makeRun(
        id: 'p-ws2',
        status: RunStatus.succeeded,
        startedAt: t0.add(const Duration(seconds: 2)),
        workspaceId: 'ws-2',
      ),
    );
    await repo.create(
      makeRun(
        id: 'c-ws2',
        status: RunStatus.succeeded,
        startedAt: t0.add(const Duration(seconds: 3)),
        workflowId: 'wf-child',
        workspaceId: 'ws-2',
        parentRunId: 'p-ws2',
      ),
    );

    final res = await repo.deleteAllOfWorkflow(
      'wf-parent',
      workspaceId: 'ws-1',
    );
    expect(res.valueOrNull, ['p-ws1', 'c-ws1']);
    expect((await repo.getById('p-ws2')).isSuccess, isTrue);
    expect((await repo.getById('c-ws2')).isSuccess, isTrue);
  });

  test(
    'deleteAllOfWorkflow of the child workflow deletes the children and leaves '
    'the parent',
    () async {
      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);
      final now = DateTime.utc(2026, 11, 20, 9);
      final workspaces = DriftWorkspaceRepository(db);
      for (final wsId in ['ws-1', 'ws-2']) {
        await workspaces.create(
          Workspace(
            id: wsId,
            name: wsId,
            rootPath: '/tmp/$wsId',
            isGit: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      final repo = DriftRunRepository(db);

      final t0 = DateTime.utc(2026, 11, 20, 10);
      await repo.create(
        makeRun(id: 'p', status: RunStatus.succeeded, startedAt: t0),
      );
      await repo.create(
        makeRun(
          id: 'c1',
          status: RunStatus.succeeded,
          startedAt: t0.add(const Duration(seconds: 1)),
          workflowId: 'wf-child',
          parentRunId: 'p',
        ),
      );

      final res = await repo.deleteAllOfWorkflow('wf-child');
      expect(res.valueOrNull, ['c1']);
      expect((await repo.getById('c1')).isFailure, isTrue);
      expect((await repo.getById('p')).isSuccess, isTrue);
    },
  );
}
