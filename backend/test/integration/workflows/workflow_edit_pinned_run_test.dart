@Timeout(Duration(seconds: 90))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';

void main() {
  late String dataDir;
  late Directory workspaceDir;
  late Backend backend;
  late SocketHttpClient http;
  late String workspaceId;

  setUp(() async {
    dataDir = (await createTempDir()).path;
    workspaceDir = await createTempDir();
    backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
    final registered = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(
        CreateWorkspaceRequest(rootPath: workspaceDir.path).toJson(),
      ),
    );
    expect(registered.statusCode, 201);
    workspaceId = Workspace.fromJson(registered.json).id;
  });

  tearDown(() {
    http.close();
  });

  Future<Workflow> createCommandWorkflow({
    required String scriptPath,
    String? workspaceId,
    String name = 'Flow',
  }) async {
    final createReq = CreateWorkflowRequest(
      name: name,
      workspaceId: workspaceId,
      entryNodeId: 'n1',
      nodes: <WorkflowNode>[
        WorkflowNode(
          id: 'n1',
          type: NodeTypeId.command,
          label: 'Run Script',
          position: const WorkflowPosition(x: 0, y: 0),
          config: <String, Object?>{
            'command': Platform.resolvedExecutable,
            'args': <String>[scriptPath],
          },
        ),
      ],
    );
    final res = await http.post(
      '/api/v1/workflows',
      body: jsonEncode(createReq.toJson()),
    );
    expect(res.statusCode, 201);
    return WorkflowResponse.fromJson(res.json).workflow;
  }

  Future<Run> startRun(String workflowId) async {
    final res = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflowId,
          workspaceId: workspaceId,
        ).toJson(),
      ),
    );
    expect(res.statusCode, 201);
    return Run.fromJson(res.json);
  }

  Future<Run> waitUntilFinished(String runId) async {
    for (var i = 0; i < 300; i++) {
      final res = await http.get('/api/v1/runs/$runId');
      expect(res.statusCode, 200);
      final run = Run.fromJson(res.json);
      if (!run.status.isActive) return run;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('Run $runId did not finish within 30s');
  }

  Future<String> writeQuickScript() async {
    final script = File(p.join(workspaceDir.path, 'quick.dart'));
    await script.writeAsString("void main() { print('hi'); }\n");
    return script.path;
  }

  Future<String> writeWaitingScript() async {
    final script = File(p.join(workspaceDir.path, 'wait.dart'));
    await script.writeAsString('''
import 'dart:async';
Future<void> main() async {
  await Future<void>.delayed(const Duration(seconds: 60));
}
''');
    return script.path;
  }

  test(
    "an edit during an active run does not change the run's pinned workflow; "
    'the next run uses the edit',
    () async {
      final waitingScript = await writeWaitingScript();
      final quickScript = await writeQuickScript();
      final workflow = await createCommandWorkflow(scriptPath: waitingScript);

      final runA = await startRun(workflow.id);
      addTearDown(() async {
        await http.post('/api/v1/runs/${runA.id}/cancel');
      });
      for (var i = 0; i < 100; i++) {
        final current = Run.fromJson(
          (await http.get('/api/v1/runs/${runA.id}')).json,
        );
        if (current.status == RunStatus.running) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      final before = WorkflowResponse.fromJson(
        (await http.get('/api/v1/workflows/${workflow.id}')).json,
      );
      final edit = await http.post(
        '/api/v1/internal/mcp/tools/edit_workflow',
        body: jsonEncode({
          'arguments': {
            'id': workflow.id,
            'revision': before.revision,
            'workspace': 'global',
            'operations': [
              {
                'op': 'update_node',
                'id': 'n1',
                'label': 'Edited',
                'config': {
                  'args': [quickScript],
                },
              },
            ],
          },
        }),
      );
      expect(edit.statusCode, 200);

      final activeA = Run.fromJson(
        (await http.get('/api/v1/runs/${runA.id}')).json,
      );
      expect(activeA.status.isActive, isTrue);
      expect(activeA.workflowDefinition.nodes.single.label, 'Run Script');
      expect(activeA.workflowDefinition.nodes.single.config['args'], [
        waitingScript,
      ]);

      final edited = WorkflowResponse.fromJson(
        (await http.get('/api/v1/workflows/${workflow.id}')).json,
      );
      expect(edited.workflow.nodes.single.label, 'Edited');

      await http.post('/api/v1/runs/${runA.id}/cancel');
      final finishedA = await waitUntilFinished(runA.id);
      expect(finishedA.workflowDefinition.nodes.single.label, 'Run Script');

      final runB = await startRun(workflow.id);
      expect(runB.workflowDefinition.nodes.single.label, 'Edited');
      final finishedB = await waitUntilFinished(runB.id);
      expect(finishedB.status.isActive, isFalse);
    },
  );
}
