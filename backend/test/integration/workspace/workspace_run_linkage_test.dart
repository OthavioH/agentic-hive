@Timeout(Duration(seconds: 60))
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
    backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
  });

  tearDown(() => http.close());

  Future<Workflow> createWorkflow() async {
    final request = CreateWorkflowRequest(
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
    );
    final response = await http.post(
      '/api/v1/workflows',
      body: jsonEncode(request.toJson()),
    );
    expect(response.statusCode, 201);
    return WorkflowResponse.fromJson(response.json).workflow;
  }

  Future<Workspace> registerWorkspace() async {
    final response = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(
        CreateWorkspaceRequest(rootPath: workspaceDir.path).toJson(),
      ),
    );
    expect(response.statusCode, 201);
    return Workspace.fromJson(response.json);
  }

  test('a run started with workspaceId belongs to that workspace and uses its '
      'root folder', () async {
    final workflow = await createWorkflow();
    final workspace = await registerWorkspace();

    final response = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflow.id,
          workspaceId: workspace.id,
          workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ).toJson(),
      ),
    );

    expect(response.statusCode, 201);
    final run = Run.fromJson(response.json);
    expect(run.workspaceId, workspace.id);
    expect(run.workspacePath, workspace.rootPath);
  });

  test('a run started with only workspacePath registers the folder as a '
      'workspace and attaches the run', () async {
    final workflow = await createWorkflow();

    final response = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflow.id,
          workspacePath: workspaceDir.path,
          workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ).toJson(),
      ),
    );

    expect(response.statusCode, 201);
    final run = Run.fromJson(response.json);
    expect(run.workspaceId, isNotNull);
    final list = await http.get('/api/v1/workspaces');
    final items = WorkspaceListResponse.fromJson(list.json).items;
    expect(items.map((w) => w.id), [run.workspaceId]);
  });

  test('a run started with an unknown workspaceId returns 404', () async {
    final workflow = await createWorkflow();

    final response = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflow.id,
          workspaceId: 'missing',
        ).toJson(),
      ),
    );

    expect(response.statusCode, 404);
  });

  test('a run started with neither workspaceId nor workspacePath returns '
      '400', () async {
    final workflow = await createWorkflow();

    final response = await http.post(
      '/api/v1/runs',
      body: jsonEncode(StartRunRequest(workflowId: workflow.id).toJson()),
    );

    expect(response.statusCode, 400);
  });

  test('the run list and run detail expose workspaceId', () async {
    final workflow = await createWorkflow();
    final workspace = await registerWorkspace();
    final started = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflow.id,
          workspaceId: workspace.id,
          workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ).toJson(),
      ),
    );
    final run = Run.fromJson(started.json);

    final detail = await http.get('/api/v1/runs/${run.id}');
    final list = await http.get('/api/v1/runs');

    expect(Run.fromJson(detail.json).workspaceId, workspace.id);
    final items = RunsListResponse.fromJson(list.json).items;
    expect(items.single.workspaceId, workspace.id);
  });
}
