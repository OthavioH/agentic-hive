import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Overview contracts', () {
    test('ActiveNodeStatus parses by name and rejects unknown values', () {
      expect(ActiveNodeStatus.fromName('running'), ActiveNodeStatus.running);
      expect(ActiveNodeStatus.fromName('paused'), ActiveNodeStatus.paused);
      expect(
        () => ActiveNodeStatus.fromName('unknown'),
        throwsA(isA<FormatException>()),
      );
    });

    test('OverviewMetrics round-trips JSON', () {
      const metrics = OverviewMetrics(
        activeRunsCount: 2,
        activeNodesCount: 3,
        pendingPausesCount: 1,
        succeededLast24hCount: 14,
        failedLast24hCount: 2,
      );
      expect(OverviewMetrics.fromJson(metrics.toJson()), metrics);
    });

    test('ActiveRunSummary round-trips JSON with and without workflowId', () {
      final withWorkflow = ActiveRunSummary(
        runId: 'run-1',
        workflowId: 'wf-1',
        workflowName: 'Implement Feature',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 21, 10, 15),
        activeNodeCount: 2,
      );
      expect(ActiveRunSummary.fromJson(withWorkflow.toJson()), withWorkflow);

      final withoutWorkflow = ActiveRunSummary(
        runId: 'run-2',
        workflowName: 'Ad-hoc Flow',
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 21, 10),
        activeNodeCount: 1,
      );
      expect(
        ActiveRunSummary.fromJson(withoutWorkflow.toJson()),
        withoutWorkflow,
      );
    });

    test('ActiveNodeSummary round-trips JSON with and without agent', () {
      final agentNode = ActiveNodeSummary(
        runId: 'run-1',
        workflowName: 'Implement Feature',
        nodeId: 'coder',
        nodeType: NodeTypeId.claudeCode,
        nodeLabel: 'Implementer',
        agentId: 'senior-dev',
        agentName: 'Senior Developer',
        status: ActiveNodeStatus.running,
        startedAt: DateTime.utc(2026, 11, 21, 10, 16),
      );
      expect(ActiveNodeSummary.fromJson(agentNode.toJson()), agentNode);

      final commandNode = ActiveNodeSummary(
        runId: 'run-1',
        workflowName: 'Implement Feature',
        nodeId: 'tests',
        nodeType: NodeTypeId.command,
        nodeLabel: 'Run tests',
        status: ActiveNodeStatus.paused,
        startedAt: DateTime.utc(2026, 11, 21, 10, 18),
      );
      expect(ActiveNodeSummary.fromJson(commandNode.toJson()), commandNode);
    });

    test('PendingPauseSummary round-trips JSON', () {
      final approvalPause = PendingPauseSummary(
        pauseId: 'pause-1',
        runId: 'run-1',
        workflowName: 'Deploy',
        nodeId: 'gate',
        nodeLabel: 'Release Gate',
        pauseKind: PauseKind.humanApproval,
        prompt: 'Verify changelog before deploying.',
        requiresFeedback: false,
        createdAt: DateTime.utc(2026, 11, 21, 10, 5),
      );
      expect(
        PendingPauseSummary.fromJson(approvalPause.toJson()),
        approvalPause,
      );

      final askPause = PendingPauseSummary(
        pauseId: 'pause-2',
        runId: 'run-2',
        workflowName: 'Build',
        nodeId: 'coder',
        nodeLabel: 'Coder',
        pauseKind: PauseKind.askHuman,
        prompt: 'Which target environment?',
        requiresFeedback: false,
        createdAt: DateTime.utc(2026, 11, 21, 10, 6),
      );
      expect(PendingPauseSummary.fromJson(askPause.toJson()), askPause);
    });

    test('OverviewSnapshot round-trips JSON', () {
      final snapshot = OverviewSnapshot(
        metrics: const OverviewMetrics(
          activeRunsCount: 1,
          activeNodesCount: 1,
          pendingPausesCount: 1,
          succeededLast24hCount: 4,
          failedLast24hCount: 1,
        ),
        activeRuns: [
          ActiveRunSummary(
            runId: 'run-1',
            workflowId: 'wf-1',
            workflowName: 'Deploy',
            status: RunStatus.paused,
            startedAt: DateTime.utc(2026, 11, 21, 10),
            activeNodeCount: 1,
          ),
        ],
        activeNodes: [
          ActiveNodeSummary(
            runId: 'run-1',
            workflowName: 'Deploy',
            nodeId: 'gate',
            nodeType: NodeTypeId.humanApproval,
            nodeLabel: 'Approve prod',
            status: ActiveNodeStatus.paused,
            startedAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
        ],
        pendingPauses: [
          PendingPauseSummary(
            pauseId: 'pause-1',
            runId: 'run-1',
            workflowName: 'Deploy',
            nodeId: 'gate',
            nodeLabel: 'Approve prod',
            pauseKind: PauseKind.humanApproval,
            prompt: 'Approve production rollout?',
            requiresFeedback: false,
            createdAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
        ],
        recentRuns: [
          RunSummary(
            id: 'run-0',
            workflowId: 'wf-1',
            workflowName: 'Deploy',
            status: RunStatus.succeeded,
            startedAt: DateTime.utc(2026, 11, 21, 8),
            finishedAt: DateTime.utc(2026, 11, 21, 8, 5),
            checkpointCount: 3,
          ),
        ],
      );

      final json = snapshot.toJson();
      final decoded = OverviewSnapshot.fromJson(json);
      expect(decoded, snapshot);
    });

    test(
      'OverviewSnapshot.fromJson throws FormatException on invalid shape',
      () {
        expect(
          () => OverviewSnapshot.fromJson(<String, Object?>{'metrics': 'bad'}),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
