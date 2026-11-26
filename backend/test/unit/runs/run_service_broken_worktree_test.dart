import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
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

import '../engine/support/engine_harness.dart';

final class _FakeGitRunner implements ProcessRunner {
  new({required this.repoPath, required this.brokenWorktreePath});

  final String repoPath;
  final String brokenWorktreePath;

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    String? stdinContent,
  }) async {
    if (arguments.contains('worktree') && arguments.contains('list')) {
      return ProcessRunResult(
        exitCode: 0,
        stdout:
            'worktree $repoPath\n'
            'HEAD 0000000000000000000000000000000000000000\n'
            'branch refs/heads/main\n'
            '\n'
            'worktree $brokenWorktreePath\n'
            'HEAD 0000000000000000000000000000000000000000\n'
            'branch refs/heads/bad\n\n',
        stderr: '',
      );
    }
    if (arguments.contains('status') && arguments.contains(repoPath)) {
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    }
    if (arguments.contains('status') &&
        arguments.contains(brokenWorktreePath)) {
      return const ProcessRunResult(
        exitCode: 128,
        stdout: '',
        stderr: 'fatal: not a git repository',
      );
    }
    throw UnimplementedError('Unexpected git call: $executable $arguments');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

void main() {
  test('startRun refuses a broken worktree and creates no run', () async {
    final root = await Directory.systemTemp.createTemp('run_broken_wt_');
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    final repo = Directory(p.join(root.path, 'repo'))..createSync();
    final worktreesDir = Directory(p.join(root.path, 'worktrees'))
      ..createSync();
    final brokenDir = Directory(p.join(worktreesDir.path, 'ws-1', 'bad'))
      ..createSync(recursive: true);

    final git = GitClient(
      _FakeGitRunner(repoPath: repo.path, brokenWorktreePath: brokenDir.path),
    );
    final workspace = Workspace(
      id: 'ws-1',
      name: 'Repo',
      rootPath: repo.path,
      isGit: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final workflow = Workflow(
      id: 'wf-1',
      name: 'Flow',
      entryNodeId: 'c',
      edges: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      nodes: const [
        WorkflowNode(
          id: 'c',
          type: NodeTypeId.command,
          label: 'Command',
          position: WorkflowPosition(x: 0, y: 0),
          config: {'command': 'echo hi'},
        ),
      ],
    );
    final harness = EngineHarness();
    final service = RunService(
      runs: harness.runs,
      checkpoints: harness.checkpoints,
      events: harness.events,
      workspaces: WorkspaceService(
        workspaces: _FakeWorkspaceRepository(workspace),
        capabilities: WorkspaceCapabilitiesService(git),
      ),
      workflows: _SingleWorkflowRepository(workflow),
      engine: harness.engine,
      workspacePreparation: WorkspacePreparationService(git: git),
      worktrees: WorktreeService(
        git: git,
        activeRuns: _FakeActiveRunLookup(),
        worktreesDir: worktreesDir.path,
      ),
    );

    final result = await service.startRun(
      const StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        target: RunTarget.worktree(worktreeId: 'bad'),
      ),
    );
    await service.waitForActiveExecutions();

    expect(result, isA<FailureResult<Run>>());
    expect(result.failureOrNull, isA<ConflictFailure>());
    expect(result.failureOrNull!.message, contains('broken'));

    final runs = await harness.runs.list();
    expect(runs.valueOrNull?.items, isEmpty);
  });
}
