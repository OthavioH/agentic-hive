@Timeout(Duration(seconds: 90))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../http/support/harness.dart';

void main() {
  late Directory workspaceDir;
  late Backend backend;
  late SocketHttpClient http;

  setUp(() async {
    final dataDir = (await createTempDir()).path;
    workspaceDir = await createTempDir();
    await _initGitRepository(workspaceDir);
    backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
  });

  tearDown(() => http.close());

  Future<String> createWorkflowId() async {
    final response = await http.post(
      '/api/v1/workflows',
      body: jsonEncode(
        CreateWorkflowRequest(
          name: 'Quick',
          entryNodeId: 'n1',
          nodes: <WorkflowNode>[
            WorkflowNode(
              id: 'n1',
              type: NodeTypeId.command,
              label: 'Run',
              position: const WorkflowPosition(x: 0, y: 0),
              config: <String, Object?>{
                'command': Platform.resolvedExecutable,
                'args': const <String>['--version'],
              },
            ),
          ],
        ).toJson(),
      ),
    );
    expect(response.statusCode, 201);
    return WorkflowResponse.fromJson(response.json).workflow.id;
  }

  Future<String> registerWorkspaceId() async {
    final response = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(
        CreateWorkspaceRequest(rootPath: workspaceDir.path).toJson(),
      ),
    );
    expect(response.statusCode, 201);
    return Workspace.fromJson(response.json).id;
  }

  Future<Run> startRun(String workflowId, String workspaceId) async {
    final response = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflowId,
          workspaceId: workspaceId,
        ).toJson(),
      ),
    );
    expect(response.statusCode, 201);
    return Run.fromJson(response.json);
  }

  test('without any setting a git workspace run uses a worktree', () async {
    final workflowId = await createWorkflowId();
    final workspaceId = await registerWorkspaceId();

    final run = await startRun(workflowId, workspaceId);

    expect(run.isolationMode, WorkspaceIsolationMode.worktree);
  });

  test(
    'the global default isolation mode applies to every workspace',
    () async {
      final workflowId = await createWorkflowId();
      final workspaceId = await registerWorkspaceId();
      final put = await http.put(
        '/api/v1/settings/execution',
        body: jsonEncode({'defaultIsolationMode': 'direct'}),
      );
      expect(put.statusCode, 200);

      final run = await startRun(workflowId, workspaceId);

      expect(run.isolationMode, WorkspaceIsolationMode.direct);
    },
  );

  test('the workspace override beats the global default', () async {
    final workflowId = await createWorkflowId();
    final workspaceId = await registerWorkspaceId();
    await http.put(
      '/api/v1/settings/execution',
      body: jsonEncode({'defaultIsolationMode': 'direct'}),
    );
    final put = await http.put(
      '/api/v1/workspaces/$workspaceId/settings',
      body: jsonEncode({'defaultIsolationMode': 'worktree'}),
    );
    expect(put.statusCode, 200);

    final run = await startRun(workflowId, workspaceId);

    expect(run.isolationMode, WorkspaceIsolationMode.worktree);
  });

  test('an explicit mode on the request beats every setting', () async {
    final workflowId = await createWorkflowId();
    final workspaceId = await registerWorkspaceId();
    await http.put(
      '/api/v1/workspaces/$workspaceId/settings',
      body: jsonEncode({'defaultIsolationMode': 'worktree'}),
    );

    final response = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflowId,
          workspaceId: workspaceId,
          workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ).toJson(),
      ),
    );

    expect(
      Run.fromJson(response.json).isolationMode,
      WorkspaceIsolationMode.direct,
    );
  });
}

Future<void> _initGitRepository(Directory directory) async {
  Future<void> git(List<String> args) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: directory.path,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  await git(['init']);
  await git([
    '-c',
    'user.name=Test',
    '-c',
    'user.email=test@example.com',
    'commit',
    '--allow-empty',
    '-m',
    'init',
  ]);
}
