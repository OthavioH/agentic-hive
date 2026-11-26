@Timeout(Duration(seconds: 90))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_backend/src/util/canonical_folder.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';

Future<void> _git(String dir, List<String> args) async {
  final result = await Process.run('git', ['-C', dir, ...args]);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void main() {
  late String dataDir;
  late Directory repoDir;
  late Backend backend;
  late SocketHttpClient http;
  late String workspaceId;
  late String workflowId;
  final started = <String>[];

  Future<String> registerWorkspace(Directory dir) async {
    final res = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(CreateWorkspaceRequest(rootPath: dir.path).toJson()),
    );
    expect(res.statusCode, 201);
    return Workspace.fromJson(res.json).id;
  }

  Future<String> createWaitingWorkflow() async {
    final scriptDir = await createTempDir();
    final script = File(p.join(scriptDir.path, 'wait.dart'));
    await script.writeAsString('''
import 'dart:async';
Future<void> main() => Future<void>.delayed(const Duration(seconds: 60));
''');
    final res = await http.post(
      '/api/v1/workflows',
      body: jsonEncode(
        CreateWorkflowRequest(
          name: 'Waiting',
          entryNodeId: 'n1',
          nodes: <WorkflowNode>[
            WorkflowNode(
              id: 'n1',
              type: NodeTypeId.command,
              label: 'Wait',
              position: const WorkflowPosition(x: 0, y: 0),
              config: <String, Object?>{
                'command': Platform.resolvedExecutable,
                'args': <String>[script.path],
              },
            ),
          ],
        ).toJson(),
      ),
    );
    expect(res.statusCode, 201);
    return WorkflowResponse.fromJson(res.json).workflow.id;
  }

  Future<SocketResponse> startRun(String wsId, RunTarget? target) async {
    final res = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflowId,
          workspaceId: wsId,
          target: target,
        ).toJson(),
      ),
    );
    if (res.statusCode == 201) started.add(Run.fromJson(res.json).id);
    return res;
  }

  Future<Worktree> createWorktree(String name) async {
    final res = await http.post(
      '/api/v1/workspaces/$workspaceId/worktrees',
      body: jsonEncode(CreateWorktreeRequest(name: name).toJson()),
    );
    expect(res.statusCode, 201);
    return Worktree.fromJson(res.json);
  }

  setUp(() async {
    started.clear();
    dataDir = (await createTempDir()).path;
    repoDir = await createTempDir();
    await _git(repoDir.path, ['init', '-b', 'main']);
    await _git(repoDir.path, ['config', 'user.email', 't@example.com']);
    await _git(repoDir.path, ['config', 'user.name', 'Test']);
    File(p.join(repoDir.path, 'a.txt')).writeAsStringSync('a');
    await _git(repoDir.path, ['add', '.']);
    await _git(repoDir.path, ['commit', '-m', 'init']);
    backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
    // Registered after the backend's own teardown, so it runs before it.
    addTearDown(() async {
      for (final id in started) {
        await http.post('/api/v1/runs/$id/cancel');
      }
      http.close();
    });
    workspaceId = await registerWorkspace(repoDir);
    workflowId = await createWaitingWorkflow();
  });

  test('primary target runs directly in the workspace root', () async {
    final res = await startRun(workspaceId, const RunTarget.primary());
    expect(res.statusCode, 201);
    final run = Run.fromJson(res.json);
    expect(run.isolationMode, WorkspaceIsolationMode.direct);
    expect(run.worktreePath, isNull);
    expect(run.workspaceId, workspaceId);
  });

  test('newWorktree target creates a hive/<runId> worktree that outlives '
      'the run', () async {
    final res = await startRun(workspaceId, const RunTarget.newWorktree());
    expect(res.statusCode, 201);
    final run = Run.fromJson(res.json);
    expect(run.isolationMode, WorkspaceIsolationMode.worktree);
    expect(run.worktreeBranch, 'hive/${run.id}');
    expect(
      p.normalize(run.worktreePath!),
      p.normalize(p.join(dataDir, 'worktrees', workspaceId, run.id)),
    );
    expect(Directory(run.worktreePath!).existsSync(), isTrue);

    await http.post('/api/v1/runs/${run.id}/cancel');
    expect((await http.delete('/api/v1/runs/${run.id}')).statusCode, 204);
    expect(
      Directory(run.worktreePath!).existsSync(),
      isTrue,
      reason: 'a worktree is removed only when the user asks',
    );
    final listed = await http.get('/api/v1/workspaces/$workspaceId/worktrees');
    final ids = WorktreeListResponse.fromJson(listed.json).items
        .map((w) => w.id);
    expect(ids, contains(run.id));
  });

  test('newWorktree honours a chosen name, branch and base', () async {
    final res = await startRun(
      workspaceId,
      const RunTarget.newWorktree(
        name: 'spike',
        branch: 'feature/spike',
        baseBranch: 'main',
      ),
    );
    expect(res.statusCode, 201);
    final run = Run.fromJson(res.json);
    expect(run.worktreeBranch, 'feature/spike');
    expect(p.basename(run.worktreePath!), 'spike');
  });

  test('worktree target runs in an existing worktree', () async {
    final worktree = await createWorktree('wt-one');
    final res = await startRun(
      workspaceId,
      RunTarget.worktree(worktreeId: worktree.id),
    );
    expect(res.statusCode, 201);
    final run = Run.fromJson(res.json);
    expect(run.isolationMode, WorkspaceIsolationMode.worktree);
    // The run records the canonical folder (symlinks and Windows 8.3 short
    // names resolved), so compare canonical forms the way the backend does.
    expect(
      canonicalFolder(run.worktreePath!, p.context),
      canonicalFolder(worktree.path, p.context),
    );
    expect(run.worktreeBranch, 'wt-one');
  });

  test('a second active run in the same worktree gets 409', () async {
    final worktree = await createWorktree('wt-busy');
    final target = RunTarget.worktree(worktreeId: worktree.id);
    expect((await startRun(workspaceId, target)).statusCode, 201);
    expect((await startRun(workspaceId, target)).statusCode, 409);
  });

  test('a second active run in the primary checkout gets 409', () async {
    expect(
      (await startRun(workspaceId, const RunTarget.primary())).statusCode,
      201,
    );
    expect(
      (await startRun(workspaceId, const RunTarget.primary())).statusCode,
      409,
    );
  });

  test('separate worktrees and the primary checkout run in parallel', () async {
    final one = await createWorktree('wt-a');
    final two = await createWorktree('wt-b');
    final codes = [
      (await startRun(workspaceId, const RunTarget.primary())).statusCode,
      (await startRun(
        workspaceId,
        RunTarget.worktree(worktreeId: one.id),
      )).statusCode,
      (await startRun(
        workspaceId,
        RunTarget.worktree(worktreeId: two.id),
      )).statusCode,
      (await startRun(workspaceId, const RunTarget.newWorktree())).statusCode,
    ];
    expect(codes, [201, 201, 201, 201]);
  });

  test('two simultaneous starts in one worktree: one 201, one 409', () async {
    final worktree = await createWorktree('wt-race');
    final target = RunTarget.worktree(worktreeId: worktree.id);
    final codes = (await Future.wait([
      startRun(workspaceId, target),
      startRun(workspaceId, target),
    ])).map((r) => r.statusCode).toList()..sort();
    expect(codes, [201, 409]);
  });

  test('the folder is free again once its run finishes', () async {
    final worktree = await createWorktree('wt-reuse');
    final target = RunTarget.worktree(worktreeId: worktree.id);
    final first = Run.fromJson((await startRun(workspaceId, target)).json);
    await http.post('/api/v1/runs/${first.id}/cancel');
    expect((await startRun(workspaceId, target)).statusCode, 201);
  });

  test('worktree target for the primary checkout runs direct and shares its '
      'lock', () async {
    final res = await startRun(
      workspaceId,
      const RunTarget.worktree(worktreeId: primaryWorktreeId),
    );
    expect(res.statusCode, 201);
    final run = Run.fromJson(res.json);
    expect(run.isolationMode, WorkspaceIsolationMode.direct);
    expect(run.worktreePath, isNull);

    final second = await startRun(workspaceId, const RunTarget.primary());
    expect(second.statusCode, 409);
  });

  test('an unknown worktree id returns 404', () async {
    final res = await startRun(
      workspaceId,
      const RunTarget.worktree(worktreeId: 'missing'),
    );
    expect(res.statusCode, 404);
  });

  test('worktree targets on a non-git workspace are rejected', () async {
    final plain = await createTempDir();
    final plainId = await registerWorkspace(plain);
    final res = await startRun(plainId, const RunTarget.newWorktree());
    expect(res.statusCode, 400);
    final direct = await startRun(plainId, const RunTarget.primary());
    expect(direct.statusCode, 201);
  });
}
