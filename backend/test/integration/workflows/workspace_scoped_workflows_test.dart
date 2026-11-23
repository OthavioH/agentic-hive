@Timeout(Duration(seconds: 60))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';
import '../websocket/support/ws_harness.dart' as ws;

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

  CreateWorkflowRequest quickWorkflow({String? workspaceId}) =>
      CreateWorkflowRequest(
        name: 'Quick',
        workspaceId: workspaceId,
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

  Future<WorkflowResponse> create({String? workspaceId}) async {
    final response = await http.post(
      '/api/v1/workflows',
      body: jsonEncode(quickWorkflow(workspaceId: workspaceId).toJson()),
    );
    expect(response.statusCode, 201);
    return WorkflowResponse.fromJson(response.json);
  }

  test('create, edit and delete a workspace workflow in its folder', () async {
    final workspace = await registerWorkspace();

    final created = await create(workspaceId: workspace.id);
    final file = File(
      p.join(workspaceDir.path, '.agentic-hive', 'workflows', 'quick.json'),
    );
    expect(created.scope, WorkflowScope.workspace);
    expect(file.existsSync(), isTrue);

    final updated = await http.put(
      '/api/v1/workflows/quick?workspaceId=${workspace.id}',
      body: jsonEncode(const UpdateWorkflowRequest(name: 'Quick v2').toJson()),
    );
    expect(updated.statusCode, 200);
    expect(file.readAsStringSync(), contains('Quick v2'));

    final deleted = await http.delete(
      '/api/v1/workflows/quick?workspaceId=${workspace.id}',
    );
    expect(deleted.statusCode, 200);
    expect(file.existsSync(), isFalse);
  });

  test('a global and a workspace workflow with the same name are both '
      'listed with their scope', () async {
    final workspace = await registerWorkspace();
    await create();
    await create(workspaceId: workspace.id);

    final both = WorkflowListResponse.fromJson(
      (await http.get('/api/v1/workflows?workspaceId=${workspace.id}')).json,
    ).workflows;
    final globalOnly = WorkflowListResponse.fromJson(
      (await http.get('/api/v1/workflows')).json,
    ).workflows;

    expect(both.map((w) => w.name), ['Quick', 'Quick']);
    expect(both.map((w) => w.scope).toSet(), {
      WorkflowScope.global,
      WorkflowScope.workspace,
    });
    expect(globalOnly.single.scope, WorkflowScope.global);
  });

  test('a run can start from a workspace workflow', () async {
    final workspace = await registerWorkspace();
    final workflow = (await create(workspaceId: workspace.id)).workflow;

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
  });

  test('an external edit of the workflow file is broadcast live', () async {
    final workspace = await registerWorkspace();
    await create(workspaceId: workspace.id);
    final client = await ws.WsTestClient.connect(backend.socketPath);
    addTearDown(client.close);
    // Give the watcher's periodic rescan time to start watching the folder.
    await Future<void>.delayed(const Duration(seconds: 3));

    final file = File(
      p.join(workspaceDir.path, '.agentic-hive', 'workflows', 'pulled.json'),
    );
    final external = quickWorkflow(workspaceId: workspace.id);
    file.writeAsStringSync(
      jsonEncode({
        'id': 'ignored',
        'name': 'Pulled from git',
        'nodes': external.nodes.map((n) => n.toJson()).toList(),
        'edges': <Object?>[],
        'entryNodeId': 'n1',
        'createdAt': DateTime.utc(2026, 11, 23).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 11, 23).toIso8601String(),
      }),
    );

    WorkflowsChangedPayload? payload;
    while (payload == null) {
      final envelope = await client.next(timeout: const Duration(seconds: 10));
      if (envelope.type == WsMessageType.workflowsChanged) {
        payload = WorkflowsChangedPayload.fromJson(envelope.payload);
      }
    }
    expect(payload.id, 'pulled');
    expect(payload.workspaceId, workspace.id);
    expect(payload.workflow?.name, 'Pulled from git');

    final listed = WorkflowListResponse.fromJson(
      (await http.get('/api/v1/workflows?workspaceId=${workspace.id}')).json,
    ).workflows;
    expect(listed.map((w) => w.id), contains('pulled'));
  });
}
