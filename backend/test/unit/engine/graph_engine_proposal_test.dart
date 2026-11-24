import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';
import 'support/fake_ports.dart';

void main() {
  late EngineHarness h;

  setUp(() => h = EngineHarness());

  Workflow proposalFlow({bool includeProposalConfig = true}) {
    final now = DateTime.utc(2026, 11, 21);
    return Workflow(
      id: 'wf-prop',
      name: 'Proposal Flow',
      nodes: [
        const WorkflowNode(
          id: 'planner',
          type: NodeTypeId.command,
          label: 'Planner',
          config: {'command': 'echo ok'},
          position: WorkflowPosition(x: 0, y: 0),
        ),
        WorkflowNode(
          id: 'gate',
          type: NodeTypeId.humanApproval,
          label: 'Gate',
          config: {
            'instructions': 'Review.',
            if (includeProposalConfig) ...{
              'proposalNodeId': 'planner',
              'proposalPath': 'issues',
              'proposalSchema': '{"type":"array"}',
            },
          },
          position: const WorkflowPosition(x: 100, y: 0),
        ),
        const WorkflowNode(
          id: 'done',
          type: NodeTypeId.command,
          label: 'Done',
          config: {'command': 'echo done'},
          position: WorkflowPosition(x: 200, y: 0),
        ),
      ],
      edges: [
        const WorkflowEdge(
          id: 'e1',
          sourceNodeId: 'planner',
          sourceOutput: NodeOutput.onSuccess,
          targetNodeId: 'gate',
        ),
        const WorkflowEdge(
          id: 'e2',
          sourceNodeId: 'gate',
          sourceOutput: NodeOutput.approved,
          targetNodeId: 'done',
        ),
        const WorkflowEdge(
          id: 'e3',
          sourceNodeId: 'gate',
          sourceOutput: NodeOutput.rejected,
          targetNodeId: 'done',
        ),
      ],
      entryNodeId: 'planner',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('GraphEngine approval proposals', () {
    test('persists proposal, schema, and source label on pause, then resumes '
        'with edited proposal', () async {
      const original = [
        {'id': 1},
      ];
      const edited = [
        {'id': 2},
      ];
      h.script.on('planner', [
        outcome(NodeOutput.onSuccess, data: {'issues': original}),
      ]);
      await h.createRun(proposalFlow());

      await h.engine.start(runId);

      final pause = h.pauses.pauses.values.single;
      expect(pause.status, PauseStatus.pending);
      expect(pause.proposal, original);
      expect(pause.proposalSchema, '{"type":"array"}');
      expect(pause.proposalSource, 'Planner');

      final resumed = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
          proposal: edited,
          edited: true,
        ),
      );
      expect(resumed.isSuccess, isTrue);
      expect(resumed.valueOrNull!.status, RunStatus.succeeded);
      final latest = h.checkpoints.checkpoints.last;
      final gateData =
          latest.nodeOutputs['gate']!['data']! as Map<String, Object?>;
      expect(gateData['proposal'], edited);
      expect(gateData['edited'], isTrue);
    });

    test('reject carries original proposal with edited false', () async {
      const original = [
        {'id': 1},
      ];
      h.script.on('planner', [
        outcome(NodeOutput.onSuccess, data: {'issues': original}),
      ]);
      await h.createRun(proposalFlow());
      await h.engine.start(runId);

      final resumed = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.rejected,
          proposal: original,
        ),
      );
      expect(resumed.isSuccess, isTrue);
      final latest = h.checkpoints.checkpoints.last;
      final gateData =
          latest.nodeOutputs['gate']!['data']! as Map<String, Object?>;
      expect(gateData['proposal'], original);
      expect(gateData['edited'], isFalse);
    });

    test(
      'fails run without pause when proposal source node has not run',
      () async {
        final now = DateTime.utc(2026, 11, 21);
        final wf = Workflow(
          id: 'wf-missing',
          name: 'Missing Source',
          nodes: const [
            WorkflowNode(
              id: 'gate',
              type: NodeTypeId.humanApproval,
              label: 'Gate',
              config: {
                'instructions': 'Review.',
                'proposalNodeId': 'planner',
                'proposalPath': 'issues',
              },
              position: WorkflowPosition(x: 0, y: 0),
            ),
          ],
          edges: const [],
          entryNodeId: 'gate',
          createdAt: now,
          updatedAt: now,
        );
        await h.createRun(wf);
        final res = await h.engine.start(runId);
        expect(res.valueOrNull!.status, RunStatus.failed);
        expect(h.pauses.pauses, isEmpty);
      },
    );

    test('approval without proposal config emits decision only', () async {
      h.script.on('planner', [outcome(NodeOutput.onSuccess)]);
      await h.createRun(proposalFlow(includeProposalConfig: false));
      await h.engine.start(runId);

      final resumed = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );
      expect(resumed.isSuccess, isTrue);
      final latest = h.checkpoints.checkpoints.last;
      final gateData =
          latest.nodeOutputs['gate']!['data']! as Map<String, Object?>;
      expect(gateData, {'decision': 'approved'});
    });
  });
}
