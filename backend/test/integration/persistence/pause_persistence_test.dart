import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/pauses/drift_pause_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
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
    name: 'Release Flow',
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
    createdAt: DateTime.utc(2026, 11, 21, 9),
    updatedAt: DateTime.utc(2026, 11, 21, 9),
  );

  Run makeRun(String id) => Run(
    id: id,
    workflowId: 'wf-1',
    workflowName: sampleWorkflow.name,
    workflowDefinition: sampleWorkflow,
    workspacePath: '/tmp/ws',
    status: RunStatus.paused,
    startedAt: DateTime.utc(2026, 11, 21, 10),
  );

  test('migrates schemaVersion 5 to 6 creating Pauses table', () async {
    // Seed a schemaVersion 5 database without the Pauses table.
    final v5Executor = NativeDatabase(dbFile);
    await v5Executor.ensureOpen(_V5SeedUser());
    await v5Executor.runCustom(
      'CREATE TABLE app_metadata (key TEXT NOT NULL PRIMARY KEY, '
      'value TEXT NOT NULL)',
    );
    await v5Executor.runCustom(
      'CREATE TABLE workflows (id TEXT NOT NULL PRIMARY KEY, '
      'name TEXT NOT NULL, description TEXT, definition_json TEXT NOT NULL, '
      'created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
    );
    await v5Executor.runCustom(
      'CREATE TABLE runs (id TEXT NOT NULL PRIMARY KEY, workflow_id TEXT, '
      'workflow_name TEXT NOT NULL, workflow_definition_json TEXT NOT NULL, '
      'workspace_path TEXT NOT NULL, status TEXT NOT NULL, '
      'started_at TEXT NOT NULL, finished_at TEXT, error_message TEXT, '
      "isolation_mode TEXT NOT NULL DEFAULT 'direct', "
      'worktree_path TEXT, worktree_branch TEXT)',
    );
    await v5Executor.runCustom(
      'CREATE TABLE checkpoints (id TEXT NOT NULL PRIMARY KEY, '
      'run_id TEXT NOT NULL, sequence INTEGER NOT NULL, '
      'completed_node_id TEXT, pending_node_ids_json TEXT NOT NULL, '
      'attempts_by_edge_json TEXT NOT NULL, '
      'circuit_breaker_count INTEGER NOT NULL, '
      'node_outputs_json TEXT NOT NULL, created_at TEXT NOT NULL)',
    );
    await v5Executor.runCustom(
      'CREATE TABLE run_events (id TEXT NOT NULL PRIMARY KEY, '
      'run_id TEXT NOT NULL, sequence INTEGER NOT NULL, type TEXT NOT NULL, '
      'node_id TEXT, edge_id TEXT, payload_json TEXT NOT NULL, '
      'created_at TEXT NOT NULL)',
    );
    await v5Executor.runCustom(
      'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, '
      'value TEXT NOT NULL, updated_at TEXT NOT NULL)',
    );
    await v5Executor.runCustom(
      'CREATE TABLE snapshots (id TEXT NOT NULL PRIMARY KEY, '
      'run_id TEXT NOT NULL, node_id TEXT, commit_hash TEXT NOT NULL, '
      'kind TEXT NOT NULL, added_count INTEGER NOT NULL, '
      'modified_count INTEGER NOT NULL, deleted_count INTEGER NOT NULL, '
      'created_at TEXT NOT NULL)',
    );
    await v5Executor.runCustom('PRAGMA user_version = 5');
    await v5Executor.close();

    final db = AppDatabase.open(dbFile);
    addTearDown(db.close);

    expect(db.schemaVersion, 13);
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='pauses'",
        )
        .get();
    expect(tables, hasLength(1));

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND tbl_name='pauses'",
        )
        .get();
    final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
    expect(
      indexNames,
      containsAll(['idx_pauses_status_created_at', 'idx_pauses_run_status']),
    );
  });

  test(
    'CRUD, filtering, markAnswered, cancelPendingForRun, and cascade delete',
    () async {
      final db = AppDatabase.open(dbFile);
      addTearDown(db.close);

      final runs = DriftRunRepository(db);
      final pauses = DriftPauseRepository(db);
      addTearDown(pauses.close);

      await runs.create(makeRun('r1'));
      await runs.create(makeRun('r2'));

      final createdEvents = <Pause>[];
      final resolvedEvents = <Pause>[];
      final sub1 = pauses.created.listen(createdEvents.add);
      final sub2 = pauses.resolved.listen(resolvedEvents.add);
      addTearDown(sub1.cancel);
      addTearDown(sub2.cancel);

      final p1 = Pause(
        id: 'p1',
        runId: 'r1',
        nodeId: 'n1',
        kind: PauseKind.humanApproval,
        status: PauseStatus.pending,
        workflowName: 'Release Flow',
        nodeLabel: 'Approve',
        title: 'Gate',
        instructions: 'Proceed?',
        createdAt: DateTime.utc(2026, 11, 21, 10, 1),
      );
      final p2 = Pause(
        id: 'p2',
        runId: 'r1',
        nodeId: 'n2',
        kind: PauseKind.askHuman,
        status: PauseStatus.pending,
        workflowName: 'Release Flow',
        nodeLabel: 'Agent',
        question: 'Which env?',
        options: const ['staging', 'prod'],
        createdAt: DateTime.utc(2026, 11, 21, 10, 2),
      );
      final p3 = Pause(
        id: 'p3',
        runId: 'r2',
        nodeId: 'n1',
        kind: PauseKind.askHuman,
        status: PauseStatus.pending,
        workflowName: 'Release Flow',
        nodeLabel: 'Agent',
        question: 'Confirm?',
        createdAt: DateTime.utc(2026, 11, 21, 10),
      );

      expect((await pauses.create(p1)).isSuccess, isTrue);
      expect((await pauses.create(p2)).isSuccess, isTrue);
      expect((await pauses.create(p3)).isSuccess, isTrue);
      await pumpEventQueue();
      expect(createdEvents.map((p) => p.id), ['p1', 'p2', 'p3']);

      // Ordered by createdAt ASC.
      final pendingAll = (await pauses.list()).valueOrNull!;
      expect(pendingAll.total, 3);
      expect(pendingAll.items.map((p) => p.id), ['p3', 'p1', 'p2']);

      final pendingR1 = (await pauses.listPendingForRun('r1')).valueOrNull!;
      expect(pendingR1.map((p) => p.id), ['p1', 'p2']);

      // Answer p1 -> 200, second answer -> ConflictFailure.
      final answered = (await pauses.markAnswered(
        'p1',
        answeredAt: DateTime.utc(2026, 11, 21, 10, 5),
        decision: 'approved',
        feedback: 'LGTM',
      )).valueOrNull!;
      expect(answered.status, PauseStatus.answered);
      expect(answered.decision, 'approved');
      expect(answered.feedback, 'LGTM');

      final secondAttempt = await pauses.markAnswered(
        'p1',
        answeredAt: DateTime.utc(2026, 11, 21, 10, 6),
        decision: 'rejected',
      );
      expect(secondAttempt.failureOrNull, isA<ConflictFailure>());

      final missingAttempt = await pauses.markAnswered(
        'missing',
        answeredAt: DateTime.utc(2026, 11, 21, 10, 6),
        decision: 'approved',
      );
      expect(missingAttempt.failureOrNull, isA<NotFoundFailure>());

      // Cancel remaining pending pauses for r1 (only p2).
      final cancelled = (await pauses.cancelPendingForRun(
        'r1',
        cancelledAt: DateTime.utc(2026, 11, 21, 10, 7),
      )).valueOrNull!;
      expect(cancelled.map((p) => p.id), ['p2']);
      expect(cancelled.single.status, PauseStatus.cancelled);

      await pumpEventQueue();
      expect(resolvedEvents.map((p) => p.id), ['p1', 'p2']);

      // Cascade delete when run r2 is marked terminal and deleted.
      await runs.updateStatus(
        'r2',
        status: RunStatus.cancelled,
        finishedAt: DateTime.utc(2026, 11, 21, 10, 8),
      );
      expect((await runs.delete('r2')).isSuccess, isTrue);
      expect(
        (await pauses.getById('p3')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    },
  );

  test('persists and reloads proposal fields across reopen', () async {
    final dir = await Directory.systemTemp.createTemp('pause_prop_');
    addTearDown(() => dir.delete(recursive: true));
    final dbFile = File('${dir.path}/test.db');

    final db1 = AppDatabase.open(dbFile);
    await DriftRunRepository(db1).create(makeRun('r1'));
    final repo1 = DriftPauseRepository(db1);
    await repo1.create(
      Pause(
        id: 'p1',
        runId: 'r1',
        nodeId: 'gate',
        kind: PauseKind.humanApproval,
        status: PauseStatus.pending,
        workflowName: 'Flow',
        nodeLabel: 'Gate',
        instructions: 'Review',
        proposal: const [
          {'id': 1},
        ],
        proposalSchema: '{"type":"array"}',
        proposalSource: 'Planner',
        createdAt: DateTime.utc(2026, 11, 21),
      ),
    );
    await repo1.markAnswered(
      'p1',
      answeredAt: DateTime.utc(2026, 11, 21, 1),
      decision: 'approved',
      editedProposal: const [
        {'id': 2},
      ],
    );
    await repo1.close();
    await db1.close();

    final db2 = AppDatabase.open(dbFile);
    addTearDown(db2.close);
    final repo2 = DriftPauseRepository(db2);
    addTearDown(repo2.close);
    final loaded = (await repo2.getById('p1')).valueOrNull!;
    expect(loaded.proposal, [
      {'id': 1},
    ]);
    expect(loaded.proposalSchema, '{"type":"array"}');
    expect(loaded.proposalSource, 'Planner');
    expect(loaded.editedProposal, [
      {'id': 2},
    ]);
  });
}

final class _V5SeedUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 5;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
