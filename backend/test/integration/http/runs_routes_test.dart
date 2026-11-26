@Timeout(Duration(seconds: 60))
library;

import 'dart:io';

import 'package:agentic_hive_backend/src/data/runs/drift_checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late String dataDir;
  late SocketHttpClient client;

  final workflow = Workflow(
    id: 'wf-1',
    name: 'Release Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Build',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 9),
    updatedAt: DateTime.utc(2026, 11, 20, 9),
  );

  setUp(() async {
    dataDir = (await createTempDir()).path;
    final dbFile = File(configFor(dataDir).databasePath);
    final db = AppDatabase.open(dbFile);
    try {
      final runs = DriftRunRepository(db);
      final checkpoints = DriftCheckpointRepository(db);
      final events = DriftRunEventRepository(db);

      await runs.create(
        Run(
          id: 'run-orphaned',
          workflowId: 'wf-1',
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspaceRoot: '/tmp/ws',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 20, 10),
        ),
      );
      await checkpoints.append(
        id: 'cp-1',
        runId: 'run-orphaned',
        completedNodeId: 'n1',
        pendingNodeIds: const [],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {
          'n1': {'ok': true},
        },
        createdAt: DateTime.utc(2026, 11, 20, 10, 1),
      );
      await events.append(
        id: 'ev-1',
        runId: 'run-orphaned',
        type: RunEventType.runStarted,
        createdAt: DateTime.utc(2026, 11, 20, 10),
      );

      await runs.create(
        Run(
          id: 'run-paused',
          workflowId: 'wf-1',
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspaceRoot: '/tmp/ws',
          status: RunStatus.paused,
          startedAt: DateTime.utc(2026, 11, 20, 11),
        ),
      );
    } finally {
      await db.close();
    }

    final backend = await startBackend(dataDir);
    client = openClient(backend.socketPath);
  });

  test(
    'recovers orphaned runs on startup and serves /api/v1/runs endpoints',
    () async {
      // List runs: run-orphaned should now be interrupted; run-paused stays
      // paused.
      final listResp = await client.get('/api/v1/runs');
      expect(listResp.statusCode, 200);
      final list = RunsListResponse.fromJson(listResp.json);
      expect(list.total, 2);
      expect(list.items.map((r) => r.id), ['run-paused', 'run-orphaned']);
      expect(list.items[0].status, RunStatus.paused);
      expect(list.items[1].status, RunStatus.interrupted);
      expect(list.items[1].checkpointCount, 1);

      // Filter by status.
      final filteredResp = await client.get('/api/v1/runs?status=interrupted');
      expect(filteredResp.statusCode, 200);
      final filtered = RunsListResponse.fromJson(filteredResp.json);
      expect(filtered.total, 1);
      expect(filtered.items.single.id, 'run-orphaned');

      // Get run details.
      final runResp = await client.get('/api/v1/runs/run-orphaned');
      expect(runResp.statusCode, 200);
      expect(Run.fromJson(runResp.json).status, RunStatus.interrupted);

      // Events with afterSequence cursor.
      final eventsResp = await client.get(
        '/api/v1/runs/run-orphaned/events?afterSequence=1',
      );
      expect(eventsResp.statusCode, 200);
      final events = RunEventsResponse.fromJson(eventsResp.json);
      expect(events.items, hasLength(1));
      expect(events.items.single.type, RunEventType.runInterrupted);
      expect(events.items.single.payload, {'reason': 'backend_restarted'});
      expect(events.lastSequence, 2);

      // Checkpoints.
      final cpResp = await client.get('/api/v1/runs/run-orphaned/checkpoints');
      expect(cpResp.statusCode, 200);
      final cps = RunCheckpointsResponse.fromJson(cpResp.json);
      expect(cps.items.single.sequence, 1);

      // Delete active (paused) run -> 409 conflict.
      final conflictResp = await client.delete('/api/v1/runs/run-paused');
      expect(conflictResp.statusCode, 409);
      expect(ApiError.fromJson(conflictResp.json).code, ApiErrorCode.conflict);

      // Delete non-active (interrupted) run -> 204 and cascades.
      final deleteResp = await client.delete('/api/v1/runs/run-orphaned');
      expect(deleteResp.statusCode, 204);

      final missingResp = await client.get('/api/v1/runs/run-orphaned');
      expect(missingResp.statusCode, 404);
      expect(ApiError.fromJson(missingResp.json).code, ApiErrorCode.notFound);

      // Origin header rejected.
      final originResp = await client.get(
        '/api/v1/runs',
        headers: {'origin': 'http://evil.example'},
      );
      expect(originResp.statusCode, 403);
      expect(
        ApiError.fromJson(originResp.json).code,
        ApiErrorCode.originNotAllowed,
      );
    },
  );
}
