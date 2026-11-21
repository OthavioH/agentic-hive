import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_recovery_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  late File dbFile;

  setUp(() {
    dbFile = databaseFileIn(createTestDir());
  });

  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Build Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Plan',
        position: WorkflowPosition(x: 0, y: 0),
      ),
      WorkflowNode(
        id: 'n2',
        type: 'harness',
        label: 'Code',
        position: WorkflowPosition(x: 200, y: 0),
      ),
    ],
    edges: const [
      WorkflowEdge(
        id: 'e1',
        sourceNodeId: 'n1',
        sourceOutput: 'onSuccess',
        targetNodeId: 'n2',
      ),
    ],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 9),
    updatedAt: DateTime.utc(2026, 11, 20, 9),
  );

  Run makeRun({
    required String id,
    required RunStatus status,
    required DateTime startedAt,
    String? workflowId = 'wf-1',
    DateTime? finishedAt,
    String? errorMessage,
  }) => Run(
    id: id,
    workflowId: workflowId,
    workflowName: sampleWorkflow.name,
    workflowDefinition: sampleWorkflow,
    workspacePath: '/tmp/ws',
    status: status,
    startedAt: startedAt,
    finishedAt: finishedAt,
    errorMessage: errorMessage,
  );

  test(
    'migrates a v2 database to v3, creating runs, checkpoints, and run_events',
    () async {
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
      await raw.runInsert(
        'INSERT INTO app_metadata (key, value) VALUES (?, ?)',
        ['installed_at', '2026-11-20T00:00:00.000Z'],
      );
      await raw.runInsert(
        'INSERT INTO workflows (id, name, definition_json, created_at, '
        'updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          'wf-1',
          'Existing',
          '{"nodes":[],"edges":[],"schemaVersion":1}',
          '2026-11-20T00:00:00.000Z',
          '2026-11-20T00:00:00.000Z',
        ],
      );
      await raw.runCustom('PRAGMA user_version = 2');
      await raw.close();

      expect(await readUserVersion(dbFile), 2);

      final db = AppDatabase.open(dbFile);
      try {
        await db.customSelect('SELECT 1').get();
        final runsRepo = DriftRunRepository(db);
        final run = makeRun(
          id: 'run-migrated',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 20, 10),
        );
        expect((await runsRepo.create(run)).isSuccess, isTrue);
        expect((await runsRepo.getById('run-migrated')).valueOrNull, run);
      } finally {
        await db.close();
      }

      expect(await readUserVersion(dbFile), 6);
      final metadata = await readMetadataRows(dbFile);
      expect(metadata['installed_at'], '2026-11-20T00:00:00.000Z');
      final indexes = await selectFromFile(
        dbFile,
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name IN ('idx_checkpoints_run_sequence', "
        "'idx_run_events_run_sequence')",
      );
      expect(indexes, hasLength(2));
    },
  );

  test(
    'repositories support monotonic sequences, filtering, and cascade delete',
    () async {
      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);

      final runsRepo = DriftRunRepository(db);
      final cpRepo = DriftCheckpointRepository(db);
      final eventsRepo = DriftRunEventRepository(db);

      final r1 = makeRun(
        id: 'run-1',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 11, 20, 10),
        finishedAt: DateTime.utc(2026, 11, 20, 10, 5),
      );
      final r2 = makeRun(
        id: 'run-2',
        status: RunStatus.failed,
        workflowId: 'wf-2',
        startedAt: DateTime.utc(2026, 11, 20, 11),
        finishedAt: DateTime.utc(2026, 11, 20, 11, 2),
        errorMessage: 'boom',
      );
      await runsRepo.create(r1);
      await runsRepo.create(r2);

      // Append checkpoints monotonically.
      final cp1 = (await cpRepo.append(
        id: 'cp-1',
        runId: 'run-1',
        completedNodeId: 'n1',
        pendingNodeIds: const ['n2'],
        attemptsByEdge: const {'e1': 1},
        circuitBreakerCount: 0,
        nodeOutputs: const {
          'n1': {'ok': true},
        },
        createdAt: DateTime.utc(2026, 11, 20, 10, 1),
      )).valueOrNull!;
      final cp2 = (await cpRepo.append(
        id: 'cp-2',
        runId: 'run-1',
        completedNodeId: 'n2',
        pendingNodeIds: const [],
        attemptsByEdge: const {'e1': 1},
        circuitBreakerCount: 0,
        nodeOutputs: const {
          'n1': {'ok': true},
          'n2': {'done': true},
        },
        createdAt: DateTime.utc(2026, 11, 20, 10, 2),
      )).valueOrNull!;
      expect(cp1.sequence, 1);
      expect(cp2.sequence, 2);

      // Explicit wrong sequence fails validation.
      final badSeq = await cpRepo.append(
        id: 'cp-bad',
        runId: 'run-1',
        pendingNodeIds: const [],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {},
        createdAt: DateTime.utc(2026, 11, 20, 10, 3),
        sequence: 99,
      );
      expect(badSeq.failureOrNull, isA<ValidationFailure>());

      // Unique (runId, sequence) enforced at SQLite level too.
      await expectLater(
        db
            .into(db.checkpoints)
            .insert(
              CheckpointsCompanion.insert(
                id: 'cp-dup',
                runId: 'run-1',
                sequence: 1,
                pendingNodeIdsJson: '[]',
                attemptsByEdgeJson: '{}',
                circuitBreakerCount: 0,
                nodeOutputsJson: '{}',
                createdAt: DateTime.utc(2026, 11, 20, 10).toIso8601String(),
              ),
            ),
        throwsA(
          predicate<Object>(
            (e) => e.toString().contains('UNIQUE constraint failed'),
          ),
        ),
      );

      // Append events monotonically and query with afterSequence + limit.
      for (var i = 1; i <= 3; i++) {
        final ev = (await eventsRepo.append(
          id: 'ev-$i',
          runId: 'run-1',
          type: RunEventType.nodeStarted,
          nodeId: 'n$i',
          createdAt: DateTime.utc(2026, 11, 20, 10, i),
        )).valueOrNull!;
        expect(ev.sequence, i);
      }
      final page = (await eventsRepo.listForRun(
        'run-1',
        afterSequence: 1,
        limit: 1,
      )).valueOrNull!;
      expect(page.items.map((e) => e.sequence), [2]);
      expect(page.lastSequence, 2);

      // List runs with checkpointCount & filters.
      final allRuns = (await runsRepo.list()).valueOrNull!;
      expect(allRuns.total, 2);
      expect(allRuns.items.map((r) => r.id), ['run-2', 'run-1']);
      expect(allRuns.items[0].checkpointCount, 0);
      expect(allRuns.items[1].checkpointCount, 2);

      final filtered = (await runsRepo.list(status: RunStatus.succeeded))
          .valueOrNull!;
      expect(filtered.total, 1);
      expect(filtered.items.single.id, 'run-1');

      // Delete run-1 cascades checkpoints and events.
      expect((await runsRepo.delete('run-1')).isSuccess, isTrue);
      expect((await cpRepo.listForRun('run-1')).valueOrNull, isEmpty);
      expect(
        (await eventsRepo.listForRun('run-1')).valueOrNull!.items,
        isEmpty,
      );
    },
  );

  test('RunRecoveryService recovers running runs, preserves paused, and '
      'resolves resume points', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    final runsRepo = DriftRunRepository(db);
    final cpRepo = DriftCheckpointRepository(db);
    final eventsRepo = DriftRunEventRepository(db);

    await runsRepo.create(
      makeRun(
        id: 'r-running-with-cp',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 10),
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r-running-no-cp',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 11),
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r-paused',
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 20, 12),
      ),
    );

    await cpRepo.append(
      id: 'cp-1',
      runId: 'r-running-with-cp',
      completedNodeId: 'n1',
      pendingNodeIds: const ['n2'],
      attemptsByEdge: const {'e1': 2},
      circuitBreakerCount: 1,
      nodeOutputs: const {
        'n1': {'summary': 'planned'},
      },
      createdAt: DateTime.utc(2026, 11, 20, 10, 1),
    );

    var idCounter = 0;
    final recovery = RunRecoveryService(
      runs: runsRepo,
      checkpoints: cpRepo,
      generateId: () => 'rec-ev-${++idCounter}',
      now: () => DateTime.utc(2026, 11, 20, 13),
    );

    final count = (await recovery.recoverOrphanedRuns()).valueOrNull!;
    expect(count, 2);

    final r1 = (await runsRepo.getById('r-running-with-cp')).valueOrNull!;
    expect(r1.status, RunStatus.interrupted);
    expect(r1.finishedAt, isNull);

    final r1Events = (await eventsRepo.listForRun('r-running-with-cp'))
        .valueOrNull!;
    expect(r1Events.items.single.type, RunEventType.runInterrupted);
    expect(r1Events.items.single.payload, {'reason': 'backend_restarted'});

    final paused = (await runsRepo.getById('r-paused')).valueOrNull!;
    expect(paused.status, RunStatus.paused);
    expect(
      (await eventsRepo.listForRun('r-paused')).valueOrNull!.items,
      isEmpty,
    );

    // Resume point with checkpoint.
    final resumeWithCp = (await recovery.resolveResumePoint(
      'r-running-with-cp',
    )).valueOrNull!;
    expect(resumeWithCp.pendingNodeIds, ['n2']);
    expect(resumeWithCp.attemptsByEdge, {'e1': 2});
    expect(resumeWithCp.circuitBreakerCount, 1);
    expect(resumeWithCp.nodeOutputs, {
      'n1': {'summary': 'planned'},
    });

    // Resume point without checkpoint falls back to entryNodeId.
    final resumeNoCp = (await recovery.resolveResumePoint('r-running-no-cp'))
        .valueOrNull!;
    expect(resumeNoCp.latestCheckpoint, isNull);
    expect(resumeNoCp.pendingNodeIds, ['n1']);
    expect(resumeNoCp.attemptsByEdge, isEmpty);
    expect(resumeNoCp.circuitBreakerCount, 0);
    expect(resumeNoCp.nodeOutputs, isEmpty);
  });

  test('updateStatus preserves finishedAt/errorMessage and delete enforces active check', () async {
    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    final runsRepo = DriftRunRepository(db);
    final finishedAt = DateTime.utc(2026, 11, 20, 12, 30);
    await runsRepo.create(
      makeRun(
        id: 'r-failed',
        status: RunStatus.failed,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        finishedAt: finishedAt,
        errorMessage: 'boom',
      ),
    );
    await runsRepo.create(
      makeRun(
        id: 'r-running',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
      ),
    );

    // Status-only update preserves existing finishedAt and errorMessage.
    final updated = (await runsRepo.updateStatus(
      'r-failed',
      status: RunStatus.interrupted,
    )).valueOrNull!;
    expect(updated.status, RunStatus.interrupted);
    expect(updated.finishedAt, finishedAt);
    expect(updated.errorMessage, 'boom');

    // Atomic delete rejects active runs with ConflictFailure.
    final conflict = await runsRepo.delete('r-running');
    expect(conflict.failureOrNull, isA<ConflictFailure>());
    expect((await runsRepo.getById('r-running')).isSuccess, isTrue);

    // Missing run returns NotFoundFailure.
    final missing = await runsRepo.delete('does-not-exist');
    expect(missing.failureOrNull, isA<NotFoundFailure>());

    // Cancelling is active (rejected); cancellationUncertain is deletable.
    await runsRepo.create(
      makeRun(
        id: 'r-cancelling',
        status: RunStatus.cancelling,
        startedAt: DateTime.utc(2026, 11, 20, 12),
      ),
    );
    expect(
      (await runsRepo.delete('r-cancelling')).failureOrNull,
      isA<ConflictFailure>(),
    );

    await runsRepo.create(
      makeRun(
        id: 'r-uncertain',
        status: RunStatus.cancellationUncertain,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        finishedAt: DateTime.utc(2026, 11, 20, 12, 1),
      ),
    );
    expect((await runsRepo.delete('r-uncertain')).isSuccess, isTrue);
  });

  test(
    'RunRecoveryService transitions cancelling runs to cancellationUncertain',
    () async {
      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);

      final runsRepo = DriftRunRepository(db);
      final cpRepo = DriftCheckpointRepository(db);
      final eventsRepo = DriftRunEventRepository(db);

      await runsRepo.create(
        makeRun(
          id: 'r-cancelling',
          status: RunStatus.cancelling,
          startedAt: DateTime.utc(2026, 11, 20, 12),
        ),
      );

      final recovery = RunRecoveryService(
        runs: runsRepo,
        checkpoints: cpRepo,
        generateId: () => 'ev-cancel-uncertain',
        now: () => DateTime.utc(2026, 11, 20, 13),
      );

      final count = (await recovery.recoverOrphanedRuns()).valueOrNull!;
      expect(count, 1);

      final recovered = (await runsRepo.getById('r-cancelling')).valueOrNull!;
      expect(recovered.status, RunStatus.cancellationUncertain);

      final events = (await eventsRepo.listForRun('r-cancelling')).valueOrNull!;
      expect(events.items.single.type, RunEventType.runCancellationUncertain);
      expect(events.items.single.payload, {'reason': 'backend_restarted'});
    },
  );
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
