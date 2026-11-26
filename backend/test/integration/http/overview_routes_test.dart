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
          workspaceRoot: '/tmp/ws',
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
          workspaceRoot: '/tmp/ws',
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
          workspaceRoot: '/tmp/ws',
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
          workspaceRoot: '/tmp/ws',
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
          workspaceRoot: '/tmp/ws',
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

  test(
    'GET /api/v1/overview handles >200 events per run, multiple active '
    'runs, cancelling runs in recentRuns, and 24h window boundaries',
    () async {
      final now = DateTime.now().toUtc();
      final cfg = configFor(dataDir);
      final longWorkflow = Workflow(
        id: 'wf-long',
        name: 'Long Flow',
        nodes: const [
          WorkflowNode(
            id: 'early-done',
            type: NodeTypeId.command,
            label: 'Early Done',
            position: WorkflowPosition(x: 0, y: 0),
            config: {'command': 'echo 1'},
          ),
          WorkflowNode(
            id: 'late-running',
            type: NodeTypeId.command,
            label: 'Late Running',
            position: WorkflowPosition(x: 100, y: 0),
            config: {'command': 'echo 2'},
          ),
          WorkflowNode(
            id: 'parallel-running',
            type: NodeTypeId.command,
            label: 'Parallel Running',
            position: WorkflowPosition(x: 200, y: 0),
            config: {'command': 'echo 3'},
          ),
        ],
        edges: const [],
        entryNodeId: 'early-done',
        createdAt: DateTime.utc(2026, 11, 21, 9),
        updatedAt: DateTime.utc(2026, 11, 21, 9),
      );

      final db = AppDatabase.open(File(cfg.databasePath));
      try {
        final runs = DriftRunRepository(db);
        final events = DriftRunEventRepository(db);

        await runs.create(
          Run(
            id: 'run-long',
            workflowId: longWorkflow.id,
            workflowName: longWorkflow.name,
            workflowDefinition: longWorkflow,
            workspaceRoot: '/tmp/ws',
            status: RunStatus.running,
            startedAt: now.subtract(const Duration(minutes: 30)),
          ),
        );
        await runs.create(
          Run(
            id: 'run-second',
            workflowId: longWorkflow.id,
            workflowName: longWorkflow.name,
            workflowDefinition: longWorkflow,
            workspaceRoot: '/tmp/ws',
            status: RunStatus.running,
            startedAt: now.subtract(const Duration(minutes: 10)),
          ),
        );
        await runs.create(
          Run(
            id: 'run-cancelling',
            workflowId: longWorkflow.id,
            workflowName: longWorkflow.name,
            workflowDefinition: longWorkflow,
            workspaceRoot: '/tmp/ws',
            status: RunStatus.cancelling,
            startedAt: now.subtract(const Duration(minutes: 5)),
          ),
        );
        await runs.create(
          Run(
            id: 'run-ok-in',
            workflowId: longWorkflow.id,
            workflowName: longWorkflow.name,
            workflowDefinition: longWorkflow,
            workspaceRoot: '/tmp/ws',
            status: RunStatus.succeeded,
            startedAt: now.subtract(const Duration(hours: 24)),
            finishedAt: now.subtract(const Duration(hours: 23, minutes: 58)),
          ),
        );
        await runs.create(
          Run(
            id: 'run-ok-out',
            workflowId: longWorkflow.id,
            workflowName: longWorkflow.name,
            workflowDefinition: longWorkflow,
            workspaceRoot: '/tmp/ws',
            status: RunStatus.succeeded,
            startedAt: now.subtract(const Duration(hours: 25)),
            finishedAt: now.subtract(const Duration(hours: 24, minutes: 2)),
          ),
        );

        // >200 events in run-long: early-done starts at seq 1, completes at seq
        // 205, and late-running starts at seq 206.
        await events.append(
          id: 'long-ev-1',
          runId: 'run-long',
          type: RunEventType.nodeStarted,
          nodeId: 'early-done',
          createdAt: now.subtract(const Duration(minutes: 29)),
        );
        for (var seq = 2; seq <= 204; seq++) {
          await events.append(
            id: 'long-ev-$seq',
            runId: 'run-long',
            type: RunEventType.snapshotWarning,
            createdAt: now.subtract(const Duration(minutes: 20)),
          );
        }
        await events.append(
          id: 'long-ev-205',
          runId: 'run-long',
          type: RunEventType.nodeCompleted,
          nodeId: 'early-done',
          createdAt: now.subtract(const Duration(minutes: 15)),
        );
        await events.append(
          id: 'long-ev-206',
          runId: 'run-long',
          type: RunEventType.nodeStarted,
          nodeId: 'late-running',
          createdAt: now.subtract(const Duration(minutes: 14)),
        );

        // Second active run with its own executing node.
        await events.append(
          id: 'second-ev-1',
          runId: 'run-second',
          type: RunEventType.nodeStarted,
          nodeId: 'parallel-running',
          createdAt: now.subtract(const Duration(minutes: 9)),
        );

        // Verify exact window boundary on DriftRunRepository directly.
        final cutoff = DateTime.utc(2026, 11, 20, 12);
        await runs.create(
          Run(
            id: 'run-boundary-exact',
            workflowId: longWorkflow.id,
            workflowName: longWorkflow.name,
            workflowDefinition: longWorkflow,
            workspaceRoot: '/tmp/ws',
            status: RunStatus.failed,
            startedAt: cutoff.subtract(const Duration(minutes: 1)),
            finishedAt: cutoff,
          ),
        );
        await runs.create(
          Run(
            id: 'run-boundary-micro-after',
            workflowId: longWorkflow.id,
            workflowName: longWorkflow.name,
            workflowDefinition: longWorkflow,
            workspaceRoot: '/tmp/ws',
            status: RunStatus.failed,
            startedAt: cutoff.subtract(const Duration(minutes: 1)),
            finishedAt: cutoff.add(const Duration(microseconds: 1)),
          ),
        );
        await runs.create(
          Run(
            id: 'run-boundary-ms-before',
            workflowId: longWorkflow.id,
            workflowName: longWorkflow.name,
            workflowDefinition: longWorkflow,
            workspaceRoot: '/tmp/ws',
            status: RunStatus.failed,
            startedAt: cutoff.subtract(const Duration(minutes: 1)),
            finishedAt: cutoff.subtract(const Duration(milliseconds: 1)),
          ),
        );

        final boundaryCount = await runs.countByStatusFinishedSince(
          RunStatus.failed,
          finishedSince: cutoff,
        );
        expect(boundaryCount.valueOrNull, 2);
      } finally {
        await db.close();
      }

      final response = await client.get('/api/v1/overview');
      expect(response.statusCode, 200);

      final snapshot = OverviewSnapshot.fromJson(
        jsonDecode(response.body) as JsonMap,
      );
      expect(snapshot.metrics.activeRunsCount, 2);
      expect(snapshot.metrics.activeNodesCount, 2);
      expect(snapshot.metrics.succeededLast24hCount, 1);
      expect(snapshot.activeRuns.map((r) => (r.runId, r.activeNodeCount)), [
        ('run-second', 1),
        ('run-long', 1),
      ]);
      expect(snapshot.activeNodes.map((n) => (n.runId, n.nodeId, n.status)), [
        ('run-second', 'parallel-running', ActiveNodeStatus.running),
        ('run-long', 'late-running', ActiveNodeStatus.running),
      ]);
      expect(snapshot.recentRuns.map((r) => r.id), contains('run-cancelling'));
    },
  );
}
