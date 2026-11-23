import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
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
    id: 'wf-g',
    name: 'Build Flow',
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
    String? workflowId = 'wf-g',
    String? workspaceId,
    DateTime? finishedAt,
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
  );

  Future<void> seedWorkspace(AppDatabase db, String id, String name) async {
    final now = DateTime.utc(2026, 11, 20, 9);
    await DriftWorkspaceRepository(db).create(
      Workspace(
        id: id,
        name: name,
        rootPath: '/tmp/$id',
        isGit: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('deletes every finished run of a global workflow across workspaces '
      'and returns their ids', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    await seedWorkspace(db, 'ws-a', 'A');
    await seedWorkspace(db, 'ws-b', 'B');

    final runsRepo = DriftRunRepository(db);
    final t0 = DateTime.utc(2026, 11, 20, 10);
    await runsRepo.create(
      makeRun(
        id: 'r1',
        workspaceId: 'ws-a',
        status: RunStatus.succeeded,
        startedAt: t0,
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r2',
        workspaceId: 'ws-b',
        status: RunStatus.failed,
        startedAt: t0.add(const Duration(minutes: 1)),
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r3',
        status: RunStatus.cancellationUncertain,
        startedAt: t0.add(const Duration(minutes: 2)),
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r4',
        workflowId: 'wf-other',
        workspaceId: 'ws-a',
        status: RunStatus.succeeded,
        startedAt: t0.add(const Duration(minutes: 3)),
      ),
    );

    final result = await runsRepo.deleteAllOfWorkflow('wf-g');

    expect(result.valueOrNull?.toSet(), {'r1', 'r2', 'r3'});
    expect((await runsRepo.getById('r4')).isSuccess, isTrue);
    expect(
      (await runsRepo.getById('r1')).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('scopes deletion to the workspace for a workspace workflow', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);
    await seedWorkspace(db, 'ws-a', 'A');
    await seedWorkspace(db, 'ws-b', 'B');

    final runsRepo = DriftRunRepository(db);
    final t0 = DateTime.utc(2026, 11, 20, 10);
    await runsRepo.create(
      makeRun(
        id: 'r1',
        workflowId: 'review',
        workspaceId: 'ws-a',
        status: RunStatus.succeeded,
        startedAt: t0,
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r2',
        workflowId: 'review',
        workspaceId: 'ws-b',
        status: RunStatus.succeeded,
        startedAt: t0.add(const Duration(minutes: 1)),
      ),
    );

    final result = await runsRepo.deleteAllOfWorkflow(
      'review',
      workspaceId: 'ws-a',
    );

    expect(result.valueOrNull, ['r1']);
    expect((await runsRepo.getById('r2')).isSuccess, isTrue);
  });

  test('refuses and deletes nothing when any run is active', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    final runsRepo = DriftRunRepository(db);
    await runsRepo.create(
      makeRun(
        id: 'r1',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 11, 20, 12),
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r2',
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 20, 12, 2),
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r3',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12, 1),
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r4',
        status: RunStatus.cancelling,
        startedAt: DateTime.utc(2026, 11, 20, 12, 3),
      ),
    );

    final result = await runsRepo.deleteAllOfWorkflow('wf-g');

    final failure = result.failureOrNull;
    expect(failure, isA<WorkflowHasActiveRunsFailure>());
    final activeFailure = failure! as WorkflowHasActiveRunsFailure;
    expect(activeFailure.activeRuns.keys.toList(), ['r3', 'r2', 'r4']);
    expect(activeFailure.activeRuns.values.toList(), [
      RunStatus.running,
      RunStatus.paused,
      RunStatus.cancelling,
    ]);
    expect(
      activeFailure.message,
      'Workflow "wf-g" has 3 active run(s). Stop them, then delete it again.',
    );
    for (final id in ['r1', 'r2', 'r3', 'r4']) {
      expect((await runsRepo.getById(id)).isSuccess, isTrue);
    }
  });

  test('cascades checkpoints and events of deleted runs', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    final runsRepo = DriftRunRepository(db);
    final cpRepo = DriftCheckpointRepository(db);
    final eventsRepo = DriftRunEventRepository(db);

    await runsRepo.create(
      makeRun(
        id: 'r1',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 11, 20, 10),
      ),
    );
    await cpRepo.append(
      id: 'cp-1',
      runId: 'r1',
      completedNodeId: 'n1',
      pendingNodeIds: const [],
      attemptsByEdge: const {},
      circuitBreakerCount: 0,
      nodeOutputs: const {},
      createdAt: DateTime.utc(2026, 11, 20, 10),
    );
    await eventsRepo.append(
      id: 'ev-1',
      runId: 'r1',
      type: RunEventType.runStarted,
      createdAt: DateTime.utc(2026, 11, 20, 10),
    );

    final result = await runsRepo.deleteAllOfWorkflow('wf-g');
    expect(result.valueOrNull, ['r1']);

    final cps = await cpRepo.listForRun('r1');
    final evs = await eventsRepo.listForRun('r1');
    expect(cps.valueOrNull, isEmpty);
    expect(evs.valueOrNull?.items, isEmpty);
  });

  test('returns an empty list when the workflow has no runs', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    final runsRepo = DriftRunRepository(db);
    final result = await runsRepo.deleteAllOfWorkflow('wf-none');

    expect(result.valueOrNull, isEmpty);
  });
}
