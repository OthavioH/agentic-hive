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

  // The default isolation mode is a client-side default: the Start Run dialog
  // preselects a target from these effective settings, and a run without a
  // target always runs in the primary checkout.
  Future<EffectiveExecutionSettings> effectiveSettings(
    String workspaceId,
  ) async {
    final response = await http.get('/api/v1/workspaces/$workspaceId/settings');
    expect(response.statusCode, 200);
    return WorkspaceSettingsResponse.fromJson(response.json).effective;
  }

  test('without any setting the effective default mode is worktree', () async {
    final workspaceId = await registerWorkspaceId();

    final effective = await effectiveSettings(workspaceId);

    expect(effective.defaultIsolationMode, WorkspaceIsolationMode.worktree);
    expect(effective.defaultShell, isNotEmpty);
  });

  test(
    'the global default isolation mode applies to every workspace',
    () async {
      final workspaceId = await registerWorkspaceId();
      final put = await http.put(
        '/api/v1/settings/execution',
        body: jsonEncode({'defaultIsolationMode': 'direct'}),
      );
      expect(put.statusCode, 200);

      final effective = await effectiveSettings(workspaceId);

      expect(effective.defaultIsolationMode, WorkspaceIsolationMode.direct);
    },
  );

  test('the workspace override beats the global default', () async {
    final workspaceId = await registerWorkspaceId();
    await http.put(
      '/api/v1/settings/execution',
      body: jsonEncode({'defaultIsolationMode': 'direct', 'defaultShell': 'a'}),
    );
    final put = await http.put(
      '/api/v1/workspaces/$workspaceId/settings',
      body: jsonEncode({
        'defaultIsolationMode': 'worktree',
        'defaultShell': 'b',
      }),
    );
    expect(put.statusCode, 200);

    final effective = await effectiveSettings(workspaceId);

    expect(effective.defaultIsolationMode, WorkspaceIsolationMode.worktree);
    expect(effective.defaultShell, 'b');
  });

  test('a run without a target ignores the default isolation mode', () async {
    final workflowId = await createWorkflowId();
    final workspaceId = await registerWorkspaceId();
    await http.put(
      '/api/v1/workspaces/$workspaceId/settings',
      body: jsonEncode({'defaultIsolationMode': 'worktree'}),
    );

    final run = await startRun(workflowId, workspaceId);

    expect(run.isolationMode, WorkspaceIsolationMode.direct);
    expect(run.worktreePath, isNull);
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
