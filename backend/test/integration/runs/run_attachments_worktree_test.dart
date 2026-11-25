@Timeout(Duration(seconds: 90))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/runs/file_run_attachment_store.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/active_run_lookup.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/worktree_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../unit/engine/support/engine_harness.dart';

final class _FakeActiveRunLookup implements ActiveRunLookup {
  @override
  Future<Result<Set<String>>> activeTargetFolders(String workspaceId) async =>
      const Success({});
}

final class _FakeWorkspaceRepository implements WorkspaceRepository {
  new(this.workspace);

  final Workspace workspace;

  @override
  Future<Result<Workspace>> getById(String id) async => Success(workspace);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SingleWorkflowRepository implements WorkflowRepository {
  new(this.workflow);

  final Workflow workflow;

  @override
  Future<Result<Workflow>> getById(String id) async => Success(workflow);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _git(String dir, List<String> args) async {
  final res = await Process.run('git', [
    '-c',
    'user.name=Test',
    '-c',
    'user.email=test@example.com',
    ...args,
  ], workingDirectory: dir);
  if (res.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${res.stderr}');
  }
}

void main() {
  test('attachment write failure cleans up newly created worktree', () async {
    final tempDir = await Directory.systemTemp.createTemp('attach_wt_');
    try {
      final repoDir = Directory(p.join(tempDir.path, 'repo'))..createSync();
      final worktreesDir = Directory(p.join(tempDir.path, 'worktrees'))
        ..createSync();
      final blockingFile = File(p.join(tempDir.path, 'runs_is_a_file'))
        ..writeAsStringSync('blocker');

      await _git(repoDir.path, ['init', '-b', 'main']);
      await File(p.join(repoDir.path, 'README.md')).writeAsString('hi\n');
      await _git(repoDir.path, ['add', '.']);
      await _git(repoDir.path, ['commit', '-m', 'init']);

      final workflow = Workflow(
        id: 'wf-1',
        name: 'Test Flow',
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

      final harness = EngineHarness();
      final runsRepo = harness.runs;
      const git = GitClient(IoProcessRunner());
      final service = RunService(
        runs: runsRepo,
        checkpoints: harness.checkpoints,
        events: harness.events,
        workspacePreparation: const WorkspacePreparationService(git: git),
        workflows: _SingleWorkflowRepository(workflow),
        workspaces: WorkspaceService(
          workspaces: _FakeWorkspaceRepository(
            Workspace(
              id: 'ws-1',
              name: 'Repo',
              rootPath: repoDir.path,
              isGit: true,
              createdAt: DateTime.utc(2026, 11, 25),
              updatedAt: DateTime.utc(2026, 11, 25),
            ),
          ),
          capabilities: const WorkspaceCapabilitiesService(git),
        ),
        worktrees: WorktreeService(
          git: git,
          activeRuns: _FakeActiveRunLookup(),
          worktreesDir: worktreesDir.path,
        ),
        engine: harness.engine,
        attachments: FileRunAttachmentStore(runsDir: blockingFile.path),
      );

      final pngBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
      ]);

      final res = await service.startRun(
        StartRunRequest(
          workflowId: 'wf-1',
          workspaceId: 'ws-1',
          target: const RunTarget.newWorktree(),
          attachments: [
            RunAttachmentPayload(
              fileName: 'shot.png',
              mimeType: 'image/png',
              data: base64Encode(pngBytes),
            ),
          ],
        ),
      );

      expect(res, isA<FailureResult<Run>>());
      expect((res as FailureResult).failure, isA<PersistenceFailure>());
      expect(runsRepo.runs, isEmpty);
      final wsWorktrees = Directory(p.join(worktreesDir.path, 'ws-1'));
      if (wsWorktrees.existsSync()) {
        expect(wsWorktrees.listSync(), isEmpty);
      }
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
