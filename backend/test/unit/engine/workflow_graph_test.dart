import 'package:agentic_hive_backend/src/domain/engine/workflow_graph.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';

void main() {
  group('WorkflowGraph', () {
    final graph = WorkflowGraph(
      buildWorkflow(
        nodeIds: ['a', 'b', 'c', 'd'],
        edges: [
          edge('a', NodeOutput.onSuccess, 'b'),
          edge('b', NodeOutput.onSuccess, 'c'),
          edge('c', NodeOutput.onFailure, 'b'),
        ],
      ),
    );

    test('looks up nodes and edges', () {
      expect(graph.node('a')?.id, 'a');
      expect(graph.node('missing'), isNull);
      expect(graph.outgoing('b').map((e) => e.targetNodeId), ['c']);
      expect(graph.incoming('b').map((e) => e.sourceNodeId), ['a', 'c']);
      expect(graph.outgoing('d'), isEmpty);
    });

    test('reaches follows one or more edges', () {
      expect(graph.reaches('a', 'c'), isTrue);
      expect(graph.reaches('c', 'a'), isFalse);
      expect(graph.reaches('a', 'd'), isFalse);
      expect(graph.reaches('a', 'a'), isFalse);
    });

    test('a node on a cycle reaches itself', () {
      expect(graph.reaches('b', 'b'), isTrue);
      expect(graph.reaches('c', 'c'), isTrue);
    });
  });
}
