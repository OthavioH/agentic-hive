import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_edit_copy.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  final workflow = Workflow(
    id: 'review-loop',
    name: 'Review loop',
    nodes: const [],
    edges: const [],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('next edge id follows the largest edge_N', () {
    final copy = WorkflowEditCopy.of(
      workflow.copyWith(
        edges: const [
          WorkflowEdge(
            id: 'edge_1',
            sourceNodeId: 'a',
            sourceOutput: 'x',
            targetNodeId: 'b',
          ),
          WorkflowEdge(
            id: 'edge_7',
            sourceNodeId: 'b',
            sourceOutput: 'x',
            targetNodeId: 'a',
          ),
        ],
      ),
    );
    expect(copy.nextEdgeId(), 'edge_8');
  });

  test('next edge id starts at edge_1 without numbered edges', () {
    final copy = WorkflowEditCopy.of(
      workflow.copyWith(
        edges: const [
          WorkflowEdge(
            id: 'a',
            sourceNodeId: 'a',
            sourceOutput: 'x',
            targetNodeId: 'b',
          ),
          WorkflowEdge(
            id: 'b',
            sourceNodeId: 'b',
            sourceOutput: 'x',
            targetNodeId: 'a',
          ),
        ],
      ),
    );
    expect(copy.nextEdgeId(), 'edge_1');
  });

  test('tally describes only non-zero parts in order', () {
    final tally = WorkflowEditTally()
      ..nodesAdded = 2
      ..autoPlaced = 1
      ..edgesRemoved = 3
      ..entrySet = 'x'
      ..metaChanged = true;
    expect(
      tally.describe(),
      '2 nodes added (1 auto-placed), 3 edges removed, entry set to x, '
      'name or description changed',
    );
  });

  test('tally omits auto-placed when zero', () {
    final tally = WorkflowEditTally()..nodesAdded = 1;
    expect(tally.describe(), '1 nodes added');
  });
}
