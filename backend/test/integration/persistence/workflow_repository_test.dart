import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/workflows/drift_workflow_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  late File dbFile;

  setUp(() {
    dbFile = databaseFileIn(createTestDir());
  });

  Workflow sampleWorkflow({
    required String id,
    required String name,
    required DateTime updatedAt,
  }) => Workflow(
    id: id,
    name: name,
    description: 'Persisted workflow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'placeholder',
        label: 'Start',
        position: WorkflowPosition(x: 100, y: 150),
        config: {'key': 'value'},
      ),
      WorkflowNode(
        id: 'n2',
        type: 'placeholder',
        label: 'Next',
        position: WorkflowPosition(x: 320, y: 150),
      ),
    ],
    edges: const [
      WorkflowEdge(
        id: 'e1',
        sourceNodeId: 'n1',
        sourceOutput: 'onSuccess',
        targetNodeId: 'n2',
        maxRetries: 2,
      ),
    ],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 10),
    updatedAt: updatedAt,
  );

  test(
    'create, read, update, list, and delete persist across restarts',
    () async {
      final firstDb = AppDatabase.open(dbFile);
      final firstRepo = DriftWorkflowRepository(firstDb);

      final wf1 = sampleWorkflow(
        id: 'wf-1',
        name: 'First',
        updatedAt: DateTime.utc(2026, 11, 20, 10),
      );
      final wf2 = sampleWorkflow(
        id: 'wf-2',
        name: 'Second',
        updatedAt: DateTime.utc(2026, 11, 20, 11),
      );

      expect((await firstRepo.create(wf1)).isSuccess, isTrue);
      expect((await firstRepo.create(wf2)).isSuccess, isTrue);
      await firstDb.close();

      // Reopen on the same SQLite file.
      final secondDb = AppDatabase.open(dbFile);
      final secondRepo = DriftWorkflowRepository(secondDb);
      try {
        final listed = (await secondRepo.listAll()).valueOrNull!;
        expect(listed.map((w) => w.id), ['wf-2', 'wf-1']);

        final fetched = (await secondRepo.getById('wf-1')).valueOrNull!;
        expect(fetched, wf1);

        final updated = wf1.copyWith(
          name: 'First Updated',
          updatedAt: DateTime.utc(2026, 11, 20, 12),
        );
        expect((await secondRepo.update(updated)).valueOrNull, updated);

        expect((await secondRepo.delete('wf-2')).isSuccess, isTrue);
        expect(
          (await secondRepo.getById('wf-2')).failureOrNull,
          isA<NotFoundFailure>(),
        );
      } finally {
        await secondDb.close();
      }

      // Verify in a third connection that update and delete survived.
      final thirdDb = AppDatabase.open(dbFile);
      final thirdRepo = DriftWorkflowRepository(thirdDb);
      try {
        final remaining = (await thirdRepo.listAll()).valueOrNull!;
        expect(remaining.map((w) => w.name), ['First Updated']);
      } finally {
        await thirdDb.close();
      }
    },
  );

  test('migrates a v1 database to v2 and creates workflows table', () async {
    // Seed a schemaVersion 1 SQLite database manually.
    final raw = NativeDatabase(dbFile);
    await raw.ensureOpen(_V1SeedUser());
    await raw.runCustom(
      'CREATE TABLE app_metadata (key TEXT NOT NULL PRIMARY KEY, '
      'value TEXT NOT NULL)',
    );
    await raw.runInsert('INSERT INTO app_metadata (key, value) VALUES (?, ?)', [
      'installed_at',
      '2026-11-20T00:00:00.000Z',
    ]);
    await raw.runCustom('PRAGMA user_version = 1');
    await raw.close();

    expect(await readUserVersion(dbFile), 1);

    final db = AppDatabase.open(dbFile);
    try {
      final repo = DriftWorkflowRepository(db);
      final wf = sampleWorkflow(
        id: 'wf-migrated',
        name: 'After Migration',
        updatedAt: DateTime.utc(2026, 11, 20, 13),
      );
      expect((await repo.create(wf)).isSuccess, isTrue);
      expect((await repo.getById('wf-migrated')).valueOrNull, wf);
    } finally {
      await db.close();
    }

    expect(await readUserVersion(dbFile), 12);
    final metadata = await readMetadataRows(dbFile);
    expect(metadata['installed_at'], '2026-11-20T00:00:00.000Z');
  });
}

final class _V1SeedUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
