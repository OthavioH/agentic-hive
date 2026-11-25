@Timeout(Duration(seconds: 90))
library;

import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/nodes/child_run_port.dart';
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
  late Directory root;
  late Directory repo;
  late Directory worktreesDir;
  late EngineHarness harness;
  late Workflow workflow;
  late RunService service;
  late String baseCommit;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('child_wt_test_');
    repo = Directory(p.join(root.path, 'repo'))..createSync();
    worktreesDir = Directory(p.join(root.path, 'worktrees'))..createSync();
    addTearDown(() async {
      try {
        await root.delete(recursive: true);
      } on FileSystemException {
        // Best effort cleanup of temp folders.
      }
    });

    await _git(repo.path, ['init']);
    await File(p.join(repo.path, 'README.md')).writeAsString('init\n');
    await _git(repo.path, ['add', '.']);
    await _git(repo.path, ['commit', '-m', 'init']);
    final rev = await Process.run('git', [
      '-C',
      repo.path,
      'rev-parse',
      'HEAD',
    ]);
    baseCommit = (rev.stdout as String).trim();

    const git = GitClient(IoProcessRunner());
    final workspace = Workspace(
      id: 'ws-1',
      name: 'Repo',
      rootPath: repo.path,
      isGit: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    harness = EngineHarness();
    workflow = Workflow(
      id: 'wf-1',
      name: 'Child Flow',
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
    service = RunService(
      runs: harness.runs,
      checkpoints: harness.checkpoints,
      events: harness.events,
      workspaces: WorkspaceService(
        workspaces: _FakeWorkspaceRepository(workspace),
        capabilities: const WorkspaceCapabilitiesService(git),
      ),
      workflows: _SingleWorkflowRepository(workflow),
      engine: harness.engine,
      workspacePreparation: const WorkspacePreparationService(git: git),
      worktrees: WorktreeService(
        git: git,
        activeRuns: _FakeActiveRunLookup(),
        worktreesDir: worktreesDir.path,
      ),
    );
  });

  tearDown(() async {
    await service.waitForActiveExecutions();
  });

  test('worktree child gets worktree from commit with hive/<id>', () async {
    final res = await service.startChildRun(
      ChildRunRequest(
        parentRunId: 'parent-1',
        parentNodeId: 'fan-1',
        index: 0,
        name: 'Item 1',
        workflow: workflow,
        workspaceId: 'ws-1',
        placement: ChildRunPlacement.worktree,
        worktreeName: 'Item-1',
        baseCommit: baseCommit,
      ),
    );

    final run = res.valueOrNull!;
    expect(run.isolationMode, WorkspaceIsolationMode.worktree);
    expect(run.worktreeBranch, 'hive/${run.id}');
    expect(Directory(run.worktreePath!).existsSync(), isTrue);

    final head = await Process.run('git', [
      '-C',
      run.worktreePath!,
      'rev-parse',
      'HEAD',
    ]);
    expect((head.stdout as String).trim(), baseCommit);
  });

  test('second child with same worktree name fails', () async {
    final first = await service.startChildRun(
      ChildRunRequest(
        parentRunId: 'parent-1',
        parentNodeId: 'fan-1',
        index: 0,
        name: 'Item 1',
        workflow: workflow,
        workspaceId: 'ws-1',
        placement: ChildRunPlacement.worktree,
        worktreeName: 'dup-wt',
        baseCommit: baseCommit,
      ),
    );
    expect(first.isSuccess, isTrue);

    final second = await service.startChildRun(
      ChildRunRequest(
        parentRunId: 'parent-1',
        parentNodeId: 'fan-1',
        index: 1,
        name: 'Item 2',
        workflow: workflow,
        workspaceId: 'ws-1',
        placement: ChildRunPlacement.worktree,
        worktreeName: 'dup-wt',
        baseCommit: baseCommit,
      ),
    );
    expect(second.failureOrNull, isA<ConflictFailure>());
  });

  test(
    'inspectParentWorkspace returns the HEAD commit and dirty state',
    () async {
      await harness.runs.create(
        Run(
          id: 'parent-1',
          workflowId: 'wf-1',
          workflowName: 'Parent',
          workflowDefinition: workflow,
          workspacePath: repo.path,
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );

      final clean = (await service.inspectParentWorkspace(runId: 'parent-1'))
          .valueOrNull!;
      expect(clean.isGit, isTrue);
      expect(clean.headCommit, baseCommit);
      expect(clean.hasUncommittedChanges, isFalse);

      await File(p.join(repo.path, 'dirty.txt')).writeAsString('dirty');
      final dirty = (await service.inspectParentWorkspace(runId: 'parent-1'))
          .valueOrNull!;
      expect(dirty.hasUncommittedChanges, isTrue);
    },
  );
}
