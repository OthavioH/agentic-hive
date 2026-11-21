@Timeout(Duration(seconds: 60))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/data/pauses/drift_pause_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late String dataDir;
  late String socketPath;
  late SocketHttpClient client;

  final workflow = Workflow(
    id: 'wf-1',
    name: 'Overview Flow',
    nodes: const [
      WorkflowNode(
        id: 'coder',
        type: NodeTypeId.claudeCode,
        label: 'Coder',
        position: WorkflowPosition(x: 0, y: 0),
        config: {'agentId': 'senior-dev'},
      ),
      WorkflowNode(
        id: 'gate',
        type: NodeTypeId.humanApproval,
        label: 'Approval Gate',
        position: WorkflowPosition(x: 100, y: 0),
        config: {'instructions': 'Verify changes.'},
      ),
    ],
    edges: const [],
    entryNodeId: 'coder',
    createdAt: DateTime.utc(2026, 11, 21, 9),
    updatedAt: DateTime.utc(2026, 11, 21, 9),
  );

  setUp(() async {
    dataDir = (await createTempDir()).path;
    socketPath = configFor(dataDir).socketPath;
    await startBackend(dataDir);
    client = SocketHttpClient(socketPath);
  });

  tearDown(() {
    client.close();
  });

  test('GET /api/v1/overview returns empty snapshot on empty DB', () async {
    final response = await client.get('/api/v1/overview');
    expect(response.statusCode, 200);

    final snapshot = OverviewSnapshot.fromJson(
      jsonDecode(response.body) as JsonMap,
    );
    expect(
      snapshot.metrics,
      const OverviewMetrics(
        activeRunsCount: 0,
        activeNodesCount: 0,
        pendingPausesCount: 0,
        succeededLast24hCount: 0,
        failedLast24hCount: 0,
      ),
    );
    expect(snapshot.activeRuns, isEmpty);
    expect(snapshot.activeNodes, isEmpty);
    expect(snapshot.pendingPauses, isEmpty);
    expect(snapshot.recentRuns, isEmpty);
  });

  test('GET /api/v1/overview aggregates real SQLite + agent data and rejects '
      'Origin', () async {
    final now = DateTime.now().toUtc();
    final cfg = configFor(dataDir);
    await Directory(cfg.agentsDir).create(recursive: true);
    await File(p.join(cfg.agentsDir, 'senior-dev.md')).writeAsString('''
---
name: Senior Developer
description: Writes clean code
---
You are a senior developer.
''');

    final db = AppDatabase.open(File(cfg.databasePath));
    try {
      final runs = DriftRunRepository(db);
      final events = DriftRunEventRepository(db);
      final pauses = DriftPauseRepository(db);

      await runs.create(
        Run(
          id: 'run-paused',
          workflowId: workflow.id,
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspacePath: '/tmp/ws',
          status: RunStatus.paused,
          startedAt: now.subtract(const Duration(minutes: 20)),
        ),
      );
      await runs.create(
        Run(
          id: 'run-running',
          workflowId: workflow.id,
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspacePath: '/tmp/ws',
          status: RunStatus.running,
          startedAt: now.subtract(const Duration(minutes: 5)),
        ),
      );
      await runs.create(
        Run(
          id: 'run-interrupted',
          workflowId: workflow.id,
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspacePath: '/tmp/ws',
          status: RunStatus.interrupted,
          startedAt: now.subtract(const Duration(minutes: 30)),
        ),
      );
      await runs.create(
        Run(
          id: 'run-succeeded-recent',
          workflowId: workflow.id,
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspacePath: '/tmp/ws',
          status: RunStatus.succeeded,
          startedAt: now.subtract(const Duration(hours: 2)),
          finishedAt: now.subtract(const Duration(hours: 1)),
        ),
      );
      await runs.create(
        Run(
          id: 'run-failed-old',
          workflowId: workflow.id,
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspacePath: '/tmp/ws',
          status: RunStatus.failed,
          startedAt: now.subtract(const Duration(hours: 30)),
          finishedAt: now.subtract(const Duration(hours: 29)),
        ),
      );

      await events.append(
        id: 'ev-1',
        runId: 'run-running',
        type: RunEventType.nodeStarted,
        nodeId: 'coder',
        createdAt: now.subtract(const Duration(minutes: 4)),
      );

      await pauses.create(
        Pause(
          id: 'pause-1',
          runId: 'run-paused',
          nodeId: 'gate',
          kind: PauseKind.humanApproval,
          status: PauseStatus.pending,
          workflowName: workflow.name,
          nodeLabel: 'Approval Gate',
          instructions: 'Verify changes.',
          createdAt: now.subtract(const Duration(minutes: 15)),
        ),
      );
    } finally {
      await db.close();
    }

    final response = await client.get('/api/v1/overview');
    expect(response.statusCode, 200);

    final snapshot = OverviewSnapshot.fromJson(
      jsonDecode(response.body) as JsonMap,
    );
    expect(
      snapshot.metrics,
      const OverviewMetrics(
        activeRunsCount: 2,
        activeNodesCount: 2,
        pendingPausesCount: 1,
        succeededLast24hCount: 1,
        failedLast24hCount: 0,
      ),
    );
    expect(snapshot.activeRuns.map((r) => r.runId).toList(), [
      'run-paused',
      'run-running',
    ]);
    expect(
      snapshot.activeNodes
          .map((n) => (n.nodeId, n.status, n.agentName, n.nodeType))
          .toList(),
      [
        (
          'coder',
          ActiveNodeStatus.running,
          'Senior Developer',
          NodeTypeId.claudeCode,
        ),
        ('gate', ActiveNodeStatus.paused, null, NodeTypeId.humanApproval),
      ],
    );
    expect(snapshot.pendingPauses.single.pauseId, 'pause-1');
    expect(snapshot.recentRuns.map((r) => r.id).toList(), [
      'run-interrupted',
      'run-succeeded-recent',
      'run-failed-old',
    ]);

    final rejected = await client.get(
      '/api/v1/overview',
      headers: {'Origin': 'http://evil.test'},
    );
    expect(rejected.statusCode, 403);
  });
}
