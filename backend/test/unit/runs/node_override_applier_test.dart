import 'package:agentic_hive_backend/src/domain/runs/node_override_applier.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

Workflow _buildWorkflow() => Workflow(
  id: 'wf-1',
  name: 'Test Workflow',
  entryNodeId: 'h',
  edges: const <WorkflowEdge>[],
  createdAt: DateTime.utc(2026, 11, 23, 10),
  updatedAt: DateTime.utc(2026, 11, 23, 10),
  nodes: const <WorkflowNode>[
    WorkflowNode(
      id: 'h',
      type: NodeTypeId.claudeCode,
      label: 'Claude',
      position: WorkflowPosition(x: 0, y: 0),
      config: <String, Object?>{
        'agentId': 'old',
        'model': 'm0',
        'effort': 'low',
        'additionalInstructions': 'keep',
      },
    ),
    WorkflowNode(
      id: 'g',
      type: NodeTypeId.geminiCli,
      label: 'Gemini',
      position: WorkflowPosition(x: 100, y: 0),
      config: <String, Object?>{'model': 'g0'},
    ),
    WorkflowNode(
      id: 'c',
      type: NodeTypeId.command,
      label: 'Command',
      position: WorkflowPosition(x: 200, y: 0),
      config: <String, Object?>{'command': 'x'},
    ),
  ],
);

void main() {
  group('NodeOverrideApplier.apply', () {
    test('returns identical instance when overrides is null', () {
      final workflow = _buildWorkflow();
      expect(NodeOverrideApplier.apply(workflow, null), same(workflow));
    });

    test('returns identical instance when overrides is empty', () {
      final workflow = _buildWorkflow();
      expect(
        NodeOverrideApplier.apply(workflow, const <String, NodeOverride>{}),
        same(workflow),
      );
    });

    test('applies full override with trimming and preserves other keys', () {
      final workflow = _buildWorkflow();
      final result = NodeOverrideApplier.apply(workflow, const {
        'h': NodeOverride(agentId: ' new ', model: 'm1', effort: 'high'),
      });
      final h = result.nodes.firstWhere((n) => n.id == 'h');
      expect(h.config['agentId'], 'new');
      expect(h.config['model'], 'm1');
      expect(h.config['effort'], 'high');
      expect(h.config['additionalInstructions'], 'keep');
    });

    test('model-only override leaves agentId and effort untouched', () {
      final workflow = _buildWorkflow();
      final result = NodeOverrideApplier.apply(workflow, const {
        'h': NodeOverride(model: 'm1'),
      });
      final h = result.nodes.firstWhere((n) => n.id == 'h');
      expect(h.config['agentId'], 'old');
      expect(h.config['model'], 'm1');
      expect(h.config['effort'], 'low');
    });

    test('blank field leaves saved value untouched', () {
      final workflow = _buildWorkflow();
      final result = NodeOverrideApplier.apply(workflow, const {
        'h': NodeOverride(model: '  ', effort: 'high'),
      });
      final h = result.nodes.firstWhere((n) => n.id == 'h');
      expect(h.config['model'], 'm0');
      expect(h.config['effort'], 'high');
    });

    test('nodes without override equal the originals', () {
      final workflow = _buildWorkflow();
      final result = NodeOverrideApplier.apply(workflow, const {
        'h': NodeOverride(model: 'm1'),
      });
      expect(
        result.nodes.firstWhere((n) => n.id == 'g'),
        workflow.nodes.firstWhere((n) => n.id == 'g'),
      );
      expect(
        result.nodes.firstWhere((n) => n.id == 'c'),
        workflow.nodes.firstWhere((n) => n.id == 'c'),
      );
    });

    test('does not mutate the input workflow', () {
      final workflow = _buildWorkflow();
      NodeOverrideApplier.apply(workflow, const {
        'h': NodeOverride(model: 'm1'),
      });
      final h = workflow.nodes.firstWhere((n) => n.id == 'h');
      expect(h.config['model'], 'm0');
    });

    test('ignores override for unknown node id without throwing', () {
      final workflow = _buildWorkflow();
      final result = NodeOverrideApplier.apply(workflow, const {
        'unknown': NodeOverride(model: 'm1'),
      });
      expect(result, workflow);
    });
  });
}
