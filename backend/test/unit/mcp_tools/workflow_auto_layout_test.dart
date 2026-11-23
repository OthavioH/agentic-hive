import 'dart:math';

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

  test('back edges do not move layers', () {
    final result = layout.layout(
      nodes: [node('a'), node('b')],
      edges: [(from: 'a', to: 'b'), (from: 'b', to: 'a')],
      entryNodeId: 'a',
    );
    expect(result['a'], const WorkflowPosition(x: 120, y: 120));
    expect(result['b'], const WorkflowPosition(x: 440, y: 120));
  });

  test('given positions are kept', () {
    const given = WorkflowPosition(x: 777, y: 333);
    final result = layout.layout(nodes: [node('a', given)], edges: []);
    expect(result['a'], given);
  });

  test('auto nodes skip a given position', () {
    const given = WorkflowPosition(x: 440, y: 120);
    final result = layout.layout(
      nodes: [node('a'), node('b'), node('c', given)],
      edges: [(from: 'a', to: 'b'), (from: 'a', to: 'c')],
      entryNodeId: 'a',
    );
    expect(result['b'], const WorkflowPosition(x: 440, y: 280));
    expect(result['c'], given);
  });

  test('unreachable nodes start a new stack in column 0', () {
    final result = layout.layout(
      nodes: [node('a'), node('z')],
      edges: [],
      entryNodeId: 'a',
    );
    expect(result['z'], const WorkflowPosition(x: 120, y: 280));
  });

  test('no entry still lays out every node', () {
    final result = layout.layout(nodes: [node('a'), node('b')], edges: []);
    expect(result.keys, containsAll(['a', 'b']));
  });

  test('no two nodes overlap', () {
    final random = Random(7);
    final nodes = [
      for (var i = 0; i < 30; i++)
        node('n$i', i < 5 ? WorkflowPosition(x: 120 + i * 300, y: 600) : null),
    ];
    final edges = <({String from, String to})>[];
    for (var i = 1; i < nodes.length; i++) {
      if (random.nextBool()) {
        edges.add((from: nodes[random.nextInt(i)].id, to: nodes[i].id));
      }
    }
    final result = layout.layout(nodes: nodes, edges: edges, entryNodeId: 'n0');
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        if (nodes[i].position != null && nodes[j].position != null) continue;
        final a = result[nodes[i].id]!;
        final b = result[nodes[j].id]!;
        expect(
          a.x < b.x + 248 &&
              b.x < a.x + 248 &&
              a.y < b.y + 112 &&
              b.y < a.y + 112,
          isFalse,
        );
      }
    }
  });

  test('same input gives same output', () {
    final nodes = [node('a'), node('b'), node('c')];
    final edges = [(from: 'a', to: 'b'), (from: 'b', to: 'c')];
    expect(
      layout.layout(nodes: nodes, edges: edges, entryNodeId: 'a'),
      layout.layout(nodes: nodes, edges: edges, entryNodeId: 'a'),
    );
  });
}
