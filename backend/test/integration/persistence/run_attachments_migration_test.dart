import 'dart:convert';

import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  test(
    'migrates schemaVersion 11 to 12 adding runs.attachments_json',
    () async {
      final dir = createTestDir();
      final dbFile = databaseFileIn(dir);

      final fresh = AppDatabase.open(dbFile);
      final repo = DriftRunRepository(fresh);

      final workflow = Workflow(
        id: 'wf-1',
        name: 'Flow',
        entryNodeId: 'n1',
        edges: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        nodes: const [
          WorkflowNode(
            id: 'n1',
            type: NodeTypeId.command,
            label: 'Run',
            position: WorkflowPosition(x: 0, y: 0),
          ),
        ],
      );

      await fresh
          .into(fresh.workspaces)
          .insert(
            WorkspacesCompanion.insert(
              id: 'ws-1',
              name: 'Workspace',
              rootPath: dir.path,
              isGit: false,
              createdAt: '2026-11-25T00:00:00.000Z',
              updatedAt: '2026-11-25T00:00:00.000Z',
            ),
          );

      final created = await repo.create(
        Run(
          id: 'run-v11',
          workflowId: 'wf-1',
          workflowName: 'Flow',
          workflowDefinition: workflow,
          workspacePath: dir.path,
          workspaceId: 'ws-1',
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 11, 25),
        ),
      );
      expect(created.isSuccess, isTrue);

      await fresh.customStatement(
        'ALTER TABLE runs DROP COLUMN attachments_json',
      );
      await fresh.customStatement('PRAGMA user_version = 11');
      await fresh.close();

      final reopened = AppDatabase.open(dbFile);
      final reopenedRepo = DriftRunRepository(reopened);

      final loaded = await reopenedRepo.getById('run-v11');
      expect(loaded.isSuccess, isTrue);
      expect(loaded.valueOrNull!.attachments, isNull);
      expect(loaded.valueOrNull!.workflowName, 'Flow');

      final withAttachments = await reopenedRepo.create(
        Run(
          id: 'run-v12',
          workflowId: 'wf-1',
          workflowName: 'Flow',
          workflowDefinition: workflow,
          workspacePath: dir.path,
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 25, 1),
          attachments: const [
            RunAttachment(
              fileName: 'a.png',
              mimeType: 'image/png',
              sizeBytes: 12,
            ),
            RunAttachment(
              fileName: 'b.jpg',
              mimeType: 'image/jpeg',
              sizeBytes: 34,
            ),
          ],
        ),
      );
      expect(withAttachments.isSuccess, isTrue);

      final loadedV12 = await reopenedRepo.getById('run-v12');
      expect(loadedV12.valueOrNull!.attachments, hasLength(2));
      expect(
        jsonEncode(loadedV12.valueOrNull!.attachments),
        jsonEncode(withAttachments.valueOrNull!.attachments),
      );

      await reopened.close();
      expect(await readUserVersion(dbFile), 12);
    },
  );
}
