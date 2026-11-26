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
  });

  tearDown(() {
    http.close();
  });

  Future<Workflow> createCommandWorkflow({required String name}) async {
    final scriptPath = p.join(workspaceDir.path, 'quick.dart');
    await File(scriptPath).writeAsString('void main() {}\n');
    final createReq = CreateWorkflowRequest(
      name: name,
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

  Future<Workflow> createFanOutWorkflow({
    required String name,
    required String targetWorkflowId,
  }) async {
    final createReq = CreateWorkflowRequest(
      name: name,
      entryNodeId: 'fan-1',
      nodes: <WorkflowNode>[
        WorkflowNode(
          id: 'fan-1',
          type: NodeTypeId.fanOut,
          label: 'Fan-out',
          position: const WorkflowPosition(x: 0, y: 0),
          config: <String, Object?>{'workflowId': targetWorkflowId},
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

  Future<WorkflowDeletionStatus> waitForDeletion(String operationId) async {
    for (var i = 0; i < 300; i++) {
      final res = await http.get('/api/v1/workflow-deletions/$operationId');
      expect(res.statusCode, 200);
      final status = WorkflowDeletionStatus.fromJson(res.json);
      if (status.phase == WorkflowDeletionPhase.done) return status;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('Deletion $operationId did not finish');
  }

  test('GET references lists the parent workflow that references the child '
      'workflow, and DELETE answer carries the same list', () async {
    final child = await createCommandWorkflow(name: 'Child Flow');
    final parent = await createFanOutWorkflow(
      name: 'Parent Flow',
      targetWorkflowId: child.id,
    );

    final refsRes = await http.get('/api/v1/workflows/${child.id}/references');
    expect(refsRes.statusCode, 200);
    final refs = WorkflowReferencesResponse.fromJson(refsRes.json);
    expect(refs.references, [
      WorkflowReference(
        workflowId: parent.id,
        workflowName: 'Parent Flow',
        nodeIds: const ['fan-1'],
      ),
    ]);

    final delRes = await http.delete('/api/v1/workflows/${child.id}');
    expect(delRes.statusCode, 202);
    final accepted = WorkflowDeletionAccepted.fromJson(delRes.json);
    expect(accepted.references, refs.references);

    final done = await waitForDeletion(accepted.operationId);
    expect(done.outcome, WorkflowDeletionOutcome.deleted);
  });
}
