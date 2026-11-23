@Timeout(Duration(seconds: 90))
library;

import 'dart:async';
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

  Future<WorkflowDeletionStatus> waitForDeletion(String operationId) async {
    for (var i = 0; i < 300; i++) {
      final res = await http.get('/api/v1/workflow-deletions/$operationId');
      expect(res.statusCode, 200);
      final status = WorkflowDeletionStatus.fromJson(res.json);
      if (status.phase == WorkflowDeletionPhase.done) return status;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('Deletion $operationId did not finish within 30s');
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

  test('global workflow: deletes finished runs, shadow repos and logs, '
      'keeps workspace files', () async {
    final keepFile = File(p.join(workspaceDir.path, 'keep.txt'));
    await keepFile.writeAsString('important');
    final scriptPath = await writeQuickScript();
    final workflow = await createCommandWorkflow(scriptPath: scriptPath);

    final r1 = await startRun(workflow.id);
    await waitUntilFinished(r1.id);
    final r2 = await startRun(workflow.id);
    await waitUntilFinished(r2.id);

    for (final runId in [r1.id, r2.id]) {
      expect(Directory(p.join(dataDir, 'runs', runId)).existsSync(), isTrue);
      expect(
        Directory(p.join(dataDir, 'snapshots', runId)).existsSync(),
        isTrue,
      );
    }

    final delRes = await http.delete('/api/v1/workflows/${workflow.id}');
    expect(delRes.statusCode, 202);
    final accepted = WorkflowDeletionAccepted.fromJson(delRes.json);
    expect(accepted.workflowId, workflow.id);
    final status = await waitForDeletion(accepted.operationId);
    expect(status.outcome, WorkflowDeletionOutcome.deleted);
    expect(status.runsDeleted, 2);
    expect(status.orphanedRuns, isEmpty);

    for (final runId in [r1.id, r2.id]) {
      expect((await http.get('/api/v1/runs/$runId')).statusCode, 404);
      expect(Directory(p.join(dataDir, 'runs', runId)).existsSync(), isFalse);
      expect(
        Directory(p.join(dataDir, 'snapshots', runId)).existsSync(),
        isFalse,
      );
    }
    expect(
      (await http.get('/api/v1/workflows/${workflow.id}')).statusCode,
      404,
    );
    expect(keepFile.existsSync(), isTrue);
    expect(keepFile.readAsStringSync(), 'important');
    expect(workspaceDir.existsSync(), isTrue);
  });

  test('workspace workflow: deletes its runs and its file only', () async {
    final keepFile = File(p.join(workspaceDir.path, 'keep.txt'));
    await keepFile.writeAsString('keep');
    final scriptPath = await writeQuickScript();

    final wsFlow = await createCommandWorkflow(
      workspaceId: workspaceId,
      scriptPath: scriptPath,
      name: 'WsFlow',
    );
    final globalFlow = await createCommandWorkflow(
      scriptPath: scriptPath,
      name: 'GlobalFlow',
    );

    final wsRun = await startRun(wsFlow.id);
    await waitUntilFinished(wsRun.id);
    final globalRun = await startRun(globalFlow.id);
    await waitUntilFinished(globalRun.id);

    final delRes = await http.delete(
      '/api/v1/workflows/${wsFlow.id}?workspaceId=$workspaceId',
    );
    expect(delRes.statusCode, 202);
    final accepted = WorkflowDeletionAccepted.fromJson(delRes.json);
    expect(accepted.workflowId, wsFlow.id);
    final status = await waitForDeletion(accepted.operationId);
    expect(status.outcome, WorkflowDeletionOutcome.deleted);
    expect(status.runsDeleted, 1);

    final wsFile = File(
      p.join(
        workspaceDir.path,
        '.agentic-hive',
        'workflows',
        '${wsFlow.id}.json',
      ),
    );
    expect(wsFile.existsSync(), isFalse);
    expect((await http.get('/api/v1/runs/${globalRun.id}')).statusCode, 200);
    expect(keepFile.existsSync(), isTrue);
  });

  test('active run: 409 with the run and nothing deleted', () async {
    final scriptPath = await writeWaitingScript();
    final workflow = await createCommandWorkflow(scriptPath: scriptPath);
    final run = await startRun(workflow.id);
    addTearDown(() async {
      await http.post('/api/v1/runs/${run.id}/cancel');
    });

    // Wait until GET shows running.
    for (var i = 0; i < 100; i++) {
      final r = Run.fromJson((await http.get('/api/v1/runs/${run.id}')).json);
      if (r.status == RunStatus.running) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    final delRes = await http.delete('/api/v1/workflows/${workflow.id}');
    expect(delRes.statusCode, 409);
    final apiError = ApiError.fromJson(delRes.json);
    expect(apiError.code, ApiErrorCode.workflowHasActiveRuns);
    expect(apiError.details, {run.id: 'running'});

    expect(
      (await http.get('/api/v1/workflows/${workflow.id}')).statusCode,
      200,
    );
    expect((await http.get('/api/v1/runs/${run.id}')).statusCode, 200);
  });

  test('force=true: stops the active run, waits, then deletes the workflow '
      'and its runs', () async {
    final scriptPath = await writeWaitingScript();
    final workflow = await createCommandWorkflow(scriptPath: scriptPath);
    final run = await startRun(workflow.id);
    addTearDown(() async {
      await http.post('/api/v1/runs/${run.id}/cancel');
    });

    // Wait until GET shows running.
    for (var i = 0; i < 100; i++) {
      final r = Run.fromJson((await http.get('/api/v1/runs/${run.id}')).json);
      if (r.status == RunStatus.running) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    final stopwatch = Stopwatch()..start();
    final delRes = await http.delete(
      '/api/v1/workflows/${workflow.id}?force=true',
    );
    stopwatch.stop();
    expect(delRes.statusCode, 202);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    final accepted = WorkflowDeletionAccepted.fromJson(delRes.json);

    final listed = WorkflowListResponse.fromJson(
      (await http.get('/api/v1/workflows')).json,
    ).workflows.where((summary) => summary.id == workflow.id);
    final current = await http.get(
      '/api/v1/workflow-deletions/${accepted.operationId}',
    );
    final deleting = WorkflowDeletionStatus.fromJson(current.json);
    expect(
      deleting.phase == WorkflowDeletionPhase.done || listed.single.deleting,
      isTrue,
    );

    final status = await waitForDeletion(accepted.operationId);
    expect(status.outcome, WorkflowDeletionOutcome.deleted);
    expect(status.runsDeleted, 1);
    expect(status.orphanedRuns, isEmpty);

    expect((await http.get('/api/v1/runs/${run.id}')).statusCode, 404);
    expect(
      (await http.get('/api/v1/workflows/${workflow.id}')).statusCode,
      404,
    );
    expect(File(scriptPath).existsSync(), isTrue);
    expect(workspaceDir.existsSync(), isTrue);
  });

  test('GET /api/v1/workflow-deletions/unknown answers 404', () async {
    final res = await http.get('/api/v1/workflow-deletions/unknown');

    expect(res.statusCode, 404);
  });
}
