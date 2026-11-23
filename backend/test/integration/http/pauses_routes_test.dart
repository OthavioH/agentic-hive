@Timeout(Duration(seconds: 60))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/data/pauses/drift_pause_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../websocket/support/ws_harness.dart';
import 'support/harness.dart';

void main() {
  late String dataDir;
  late String socketPath;
  late SocketHttpClient client;

  final workflow = Workflow(
    id: 'wf-1',
    name: 'Approval Flow',
    nodes: const [
      WorkflowNode(
        id: 'gate',
        type: 'human_approval',
        label: 'Gate',
        position: WorkflowPosition(x: 0, y: 0),
        config: {
          'title': 'Approve release',
          'instructions': 'Verify notes.',
          'allowFeedback': true,
        },
      ),
    ],
    edges: const [],
    entryNodeId: 'gate',
    createdAt: DateTime.utc(2026, 11, 21, 9),
    updatedAt: DateTime.utc(2026, 11, 21, 9),
  );

  setUp(() async {
    dataDir = (await createTempDir()).path;
    final dbFile = File(configFor(dataDir).databasePath);
    final db = AppDatabase.open(dbFile);
    try {
      final runs = DriftRunRepository(db);
      final pauses = DriftPauseRepository(db);

      await runs.create(
        Run(
          id: 'run-paused-1',
          workflowId: 'wf-1',
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspacePath: '/tmp/ws',
          status: RunStatus.paused,
          startedAt: DateTime.utc(2026, 11, 21, 10),
        ),
      );
      await pauses.create(
        Pause(
          id: 'pause-1',
          runId: 'run-paused-1',
          nodeId: 'gate',
          kind: PauseKind.humanApproval,
          status: PauseStatus.pending,
          workflowName: workflow.name,
          nodeLabel: 'Gate',
          title: 'Approve release',
          instructions: 'Verify notes.',
          createdAt: DateTime.utc(2026, 11, 21, 10, 1),
        ),
      );
      await pauses.create(
        Pause(
          id: 'pause-2',
          runId: 'run-paused-1',
          nodeId: 'other',
          kind: PauseKind.askHuman,
          status: PauseStatus.cancelled,
          workflowName: workflow.name,
          nodeLabel: 'Other',
          question: 'Old?',
          createdAt: DateTime.utc(2026, 11, 21, 10),
          answeredAt: DateTime.utc(2026, 11, 21, 10, 2),
        ),
      );
      await pauses.close();
    } finally {
      await db.close();
    }

    final backend = await startBackend(dataDir);
    socketPath = backend.socketPath;
    client = openClient(socketPath);
  });

  test(
    'lists, gets, answers (200/400/404/409), rejects Origin, and broadcasts WS',
    () async {
      final ws = await WsTestClient.connect(socketPath);
      addTearDown(ws.close);
      await ws.next(); // server.hello

      // Rejects Origin header.
      final originResp = await client.get(
        '/api/v1/pauses',
        headers: {'origin': 'http://evil.example'},
      );
      expect(originResp.statusCode, 403);

      // Defaults to status=pending.
      final listResp = await client.get('/api/v1/pauses');
      expect(listResp.statusCode, 200);
      final listed = PausesListResponse.fromJson(
        jsonDecode(listResp.body) as JsonMap,
      );
      expect(listed.total, 1);
      expect(listed.items.single.id, 'pause-1');

      // status=all includes cancelled pause-2, ordered createdAt ASC.
      final allResp = await client.get('/api/v1/pauses?status=all');
      expect(allResp.statusCode, 200);
      final all = PausesListResponse.fromJson(
        jsonDecode(allResp.body) as JsonMap,
      );
      expect(all.items.map((p) => p.id), ['pause-2', 'pause-1']);

      // Get by id: 200 & 404.
      expect((await client.get('/api/v1/pauses/pause-1')).statusCode, 200);
      expect((await client.get('/api/v1/pauses/missing')).statusCode, 404);

      // Invalid payload -> 400.
      final badResp = await client.post(
        '/api/v1/pauses/pause-1/answer',
        body: jsonEncode(const {'decision': 'invalid'}),
      );
      expect(badResp.statusCode, 400);

      // Answer pause-1 -> 200 + pause.resolved WS frame.
      final answerResp = await client.post(
        '/api/v1/pauses/pause-1/answer',
        body: jsonEncode(const {'decision': 'approved', 'feedback': 'Ship it'}),
      );
      expect(answerResp.statusCode, 200);
      final answered = Pause.fromJson(jsonDecode(answerResp.body) as JsonMap);
      expect(answered.status, PauseStatus.answered);
      expect(answered.decision, 'approved');

      // Wait for pause.resolved on WebSocket.
      WsEnvelope? resolvedFrame;
      for (var i = 0; i < 10; i++) {
        final frame = await ws.next();
        if (frame.type == WsMessageType.pauseResolved) {
          resolvedFrame = frame;
          break;
        }
      }
      expect(resolvedFrame, isNotNull);
      final wsPayload = PauseResolvedPayload.fromJson(resolvedFrame!.payload);
      expect(wsPayload.pause.id, 'pause-1');
      expect(wsPayload.pause.status, PauseStatus.answered);

      // Answering again -> 409 Conflict.
      final conflictResp = await client.post(
        '/api/v1/pauses/pause-1/answer',
        body: jsonEncode(const {'decision': 'rejected'}),
      );
      expect(conflictResp.statusCode, 409);
    },
  );
}
