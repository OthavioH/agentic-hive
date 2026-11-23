import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_auto_layout.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  const layout = WorkflowAutoLayout();
  AutoLayoutNode node(String id, [WorkflowPosition? position]) =>
      AutoLayoutNode(id: id, position: position);

  test('a chain goes left to right in one row', () {
    final result = layout.layout(
      nodes: [node('plan'), node('code'), node('review'), node('fix')],
      edges: [
        (from: 'plan', to: 'code'),
        (from: 'code', to: 'review'),
        (from: 'review', to: 'fix'),
      ],
      entryNodeId: 'plan',
    );
    expect(result['plan'], const WorkflowPosition(x: 120, y: 120));
    expect(result['code'], const WorkflowPosition(x: 440, y: 120));
    expect(result['review'], const WorkflowPosition(x: 760, y: 120));
    expect(result['fix'], const WorkflowPosition(x: 1080, y: 120));
  });

  test('branches stack in the next column', () {
    final result = layout.layout(
      nodes: [node('a'), node('b'), node('c')],
      edges: [(from: 'a', to: 'b'), (from: 'a', to: 'c')],
      entryNodeId: 'a',
    );
    expect(result['b'], const WorkflowPosition(x: 440, y: 120));
    expect(result['c'], const WorkflowPosition(x: 440, y: 280));
  });
}
