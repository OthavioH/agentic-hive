@Timeout(Duration(seconds: 60))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

import '../http/support/harness.dart';

Future<IOWebSocketChannel> _connectWs(String socketPath) async {
  final client = HttpClient()
    ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
  final socket = await WebSocket.connect(
    'ws://localhost/ws',
    customClient: client,
  );
  return IOWebSocketChannel(socket);
}

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

  Future<Workflow> createCommandWorkflow(String scriptPath) async {
    final createReq = CreateWorkflowRequest(
      name: 'Command Flow',
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

  test('POST /runs starts asynchronously, enforces 409 on direct conflict, '
      'streams run.event/run.output, and serves node logs', () async {
    final script = File(p.join(workspaceDir.path, 'echo_and_wait.dart'));
    await script.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  stdout.writeln('hello stdout');
  stderr.writeln('hello stderr');
  await Future<void>.delayed(const Duration(milliseconds: 400));
}
''');

    final workflow = await createCommandWorkflow(script.path);

    final ws = await _connectWs(backend.socketPath);
    final received = <WsEnvelope>[];
    final sub = ws.stream.listen((frame) {
      received.add(WsEnvelope.decode(frame as String));
    });
    addTearDown(() async {
      await sub.cancel();
      await ws.sink.close();
    });

    // Wait for server.hello.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final startRes = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflow.id,
          workspaceId: workspaceId,
          workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ).toJson(),
      ),
    );
    expect(startRes.statusCode, 201);
    final run = Run.fromJson(startRes.json);
    expect(run.status, RunStatus.running);

    // Subscribe to run.output for this run.
    ws.sink.add(
      WsEnvelope(
        type: WsMessageType.runSubscribe,
        id: 'sub-1',
        payload: RunSubscribePayload(runId: run.id).toJson(),
      ).encode(),
    );

    // Second active direct-mode run on the same workspace returns 409.
    final conflictRes = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflow.id,
          workspaceId: workspaceId,
          workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ).toJson(),
      ),
    );
    expect(conflictRes.statusCode, 409);

    // Wait for run to finish and for the terminal run.event + run.output
    // frames (which are emitted and delivered over the WebSocket after the
    // run's status transaction commits in _finishTerminal) to arrive.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    var current = run;
    bool hasTerminalWsEvent() => received
        .where((e) => e.type == WsMessageType.runEvent)
        .map((e) => RunEventPayload.fromJson(e.payload).event)
        .any(
          (ev) => ev.runId == run.id && ev.type == RunEventType.runSucceeded,
        );
    bool hasExpectedWsOutputs() {
      final chunks = received
          .where((e) => e.type == WsMessageType.runOutput)
          .map((e) => RunOutputPayload.fromJson(e.payload))
          .toList();
      return chunks.any((o) => o.chunk.contains('hello stdout')) &&
          chunks.any(
            (o) =>
                o.stream == RunOutputStream.stderr &&
                o.chunk.contains('hello stderr'),
          );
    }

    while (current.status.isActive ||
        !hasTerminalWsEvent() ||
        !hasExpectedWsOutputs()) {
      if (DateTime.now().isAfter(deadline)) {
        fail(
          'Timed out waiting for run to complete and deliver WS frames '
          '(status=${current.status.name}, '
          'terminalEvent=${hasTerminalWsEvent()}, '
          'outputs=${hasExpectedWsOutputs()}).',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (current.status.isActive) {
        final poll = await http.get('/api/v1/runs/${run.id}');
        current = Run.fromJson(poll.json);
      }
    }
    expect(current.status, RunStatus.succeeded);

    // Global run.event frames arrived.
    final runEventTypes = received
        .where((e) => e.type == WsMessageType.runEvent)
        .map((e) => RunEventPayload.fromJson(e.payload).event.type)
        .toList();
    expect(runEventTypes, contains(RunEventType.runStarted));
    expect(runEventTypes, contains(RunEventType.runSucceeded));

    // Subscribed run.output frames arrived.
    final outputs = received
        .where((e) => e.type == WsMessageType.runOutput)
        .map((e) => RunOutputPayload.fromJson(e.payload))
        .toList();
    expect(outputs.any((o) => o.chunk.contains('hello stdout')), isTrue);
    expect(
      outputs.any(
        (o) =>
            o.stream == RunOutputStream.stderr &&
            o.chunk.contains('hello stderr'),
      ),
      isTrue,
    );

    // Unsubscribe works cleanly.
    ws.sink.add(
      WsEnvelope(
        type: WsMessageType.runUnsubscribe,
        id: 'unsub-1',
        payload: RunUnsubscribePayload(runId: run.id).toJson(),
      ).encode(),
    );

    // GET /api/v1/runs/:id/nodes/:nodeId/logs returns stored attempt logs.
    final logsRes = await http.get('/api/v1/runs/${run.id}/nodes/n1/logs');
    expect(logsRes.statusCode, 200);
    final logs = RunNodeLogsResponse.fromJson(logsRes.json);
    expect(logs.attempt, 1);
    expect(logs.availableAttempts, [1]);
    expect(logs.offset, greaterThanOrEqualTo(2));
    expect(
      logs.entries.every((e) => e.offset >= 1 && e.offset <= logs.offset),
      isTrue,
    );
    expect(logs.entries.any((e) => e.chunk.contains('hello stdout')), isTrue);

    // DELETE cleans up log directory too.
    final delRes = await http.delete('/api/v1/runs/${run.id}');
    expect(delRes.statusCode, 204);
    expect(Directory(p.join(dataDir, 'runs', run.id)).existsSync(), isFalse);
  });

  test(
    'two simultaneous POST /runs in direct mode on the same workspace return '
    'one 201 and one 409',
    () async {
      final script = File(p.join(workspaceDir.path, 'concurrent.dart'));
      await script.writeAsString('''
import 'dart:async';
Future<void> main() => Future<void>.delayed(const Duration(milliseconds: 300));
''');
      final workflow = await createCommandWorkflow(script.path);
      final body = jsonEncode(
        StartRunRequest(
          workflowId: workflow.id,
          workspaceId: workspaceId,
          workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ).toJson(),
      );

      final responses = await Future.wait([
        http.post('/api/v1/runs', body: body),
        http.post('/api/v1/runs', body: body),
      ]);
      final codes = responses.map((r) => r.statusCode).toList()..sort();
      expect(codes, [201, 409]);

      final createdRun = Run.fromJson(
        responses.firstWhere((r) => r.statusCode == 201).json,
      );
      await http.post('/api/v1/runs/${createdRun.id}/cancel');
    },
  );

  test('POST /runs/:id/cancel terminates a running command node', () async {
    final script = File(p.join(workspaceDir.path, 'long_wait.dart'));
    await script.writeAsString('''
import 'dart:async';
Future<void> main() => Future<void>.delayed(const Duration(seconds: 60));
''');

    final workflow = await createCommandWorkflow(script.path);
    final startRes = await http.post(
      '/api/v1/runs',
      body: jsonEncode(
        StartRunRequest(
          workflowId: workflow.id,
          workspaceId: workspaceId,
          workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ).toJson(),
      ),
    );
    expect(startRes.statusCode, 201);
    final run = Run.fromJson(startRes.json);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final cancelRes = await http.post('/api/v1/runs/${run.id}/cancel');
    expect(cancelRes.statusCode, 200);
    final cancelled = Run.fromJson(cancelRes.json);
    expect(cancelled.status, RunStatus.cancelled);
  });

  test(
    'POST /runs/:id/resume rejects paused (409) and resumes interrupted',
    () async {
      final script = File(p.join(workspaceDir.path, 'quick.dart'));
      await script.writeAsString('void main() {}');
      final workflow = await createCommandWorkflow(script.path);

      final wsPaused = await Directory(p.join(workspaceDir.path, 'paused'))
          .create();
      final wsInterrupted = await Directory(
        p.join(workspaceDir.path, 'interrupted'),
      ).create();

      // Seed a paused run and an interrupted run directly in SQLite.
      final db = AppDatabase.open(File(configFor(dataDir).databasePath));
      try {
        final runsRepo = DriftRunRepository(db);
        await runsRepo.create(
          Run(
            id: 'run-paused',
            workflowId: workflow.id,
            workflowName: workflow.name,
            workflowDefinition: workflow,
            workspacePath: wsPaused.path,
            status: RunStatus.paused,
            startedAt: DateTime.utc(2026, 11, 20, 10),
          ),
        );
        await runsRepo.create(
          Run(
            id: 'run-interrupted',
            workflowId: workflow.id,
            workflowName: workflow.name,
            workflowDefinition: workflow,
            workspacePath: wsInterrupted.path,
            status: RunStatus.interrupted,
            startedAt: DateTime.utc(2026, 11, 20, 10),
          ),
        );
        await runsRepo.create(
          Run(
            id: 'run-uncertain',
            workflowId: workflow.id,
            workflowName: workflow.name,
            workflowDefinition: workflow,
            workspacePath: workspaceDir.path,
            status: RunStatus.cancellationUncertain,
            startedAt: DateTime.utc(2026, 11, 20, 10),
            finishedAt: DateTime.utc(2026, 11, 20, 10, 1),
          ),
        );
      } finally {
        await db.close();
      }

      // Paused -> 409 Conflict.
      final pausedRes = await http.post('/api/v1/runs/run-paused/resume');
      expect(pausedRes.statusCode, 409);

      // Simultaneous duplicate Resume on interrupted -> one 200 OK, one 409.
      final resumeResponses = await Future.wait([
        http.post('/api/v1/runs/run-interrupted/resume'),
        http.post('/api/v1/runs/run-interrupted/resume'),
      ]);
      final resumeCodes = resumeResponses.map((r) => r.statusCode).toList()
        ..sort();
      expect(resumeCodes, [200, 409]);

      final deadline = DateTime.now().add(const Duration(seconds: 15));
      var status = RunStatus.running;
      while (status.isActive) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for resumed run to complete.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final poll = await http.get('/api/v1/runs/run-interrupted');
        status = Run.fromJson(poll.json).status;
      }
      expect(status, RunStatus.succeeded);

      // DELETE cancellationUncertain -> 204 No Content.
      final delRes = await http.delete('/api/v1/runs/run-uncertain');
      expect(delRes.statusCode, 204);
      final checkRes = await http.get('/api/v1/runs/run-uncertain');
      expect(checkRes.statusCode, 404);
    },
  );
}
