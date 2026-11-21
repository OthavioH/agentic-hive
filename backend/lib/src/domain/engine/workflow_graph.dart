import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Read-only topology of a frozen [Workflow]: node lookup, edges by source or
/// target, and reachability used by the engine's fan-in barrier.
final class WorkflowGraph {
  /// Indexes [workflow] for traversal.
  new(Workflow workflow)
    : _nodes = <String, WorkflowNode>{
        for (final node in workflow.nodes) node.id: node,
      },
      _outgoing = <String, List<WorkflowEdge>>{},
      _incoming = <String, List<WorkflowEdge>>{} {
    for (final edge in workflow.edges) {
      (_outgoing[edge.sourceNodeId] ??= <WorkflowEdge>[]).add(edge);
      (_incoming[edge.targetNodeId] ??= <WorkflowEdge>[]).add(edge);
    }
  }

  final Map<String, WorkflowNode> _nodes;
  final Map<String, List<WorkflowEdge>> _outgoing;
  final Map<String, List<WorkflowEdge>> _incoming;
  final Map<String, Set<String>> _reachable = <String, Set<String>>{};

  /// The node with [id], or `null` when the workflow has no such node.
  WorkflowNode? node(String id) => _nodes[id];

  /// Edges leaving [nodeId], in workflow order.
  List<WorkflowEdge> outgoing(String nodeId) =>
      _outgoing[nodeId] ?? const <WorkflowEdge>[];

  /// Edges entering [nodeId], in workflow order.
  List<WorkflowEdge> incoming(String nodeId) =>
      _incoming[nodeId] ?? const <WorkflowEdge>[];

  /// Whether [to] can be reached from [from] by following one or more edges
  /// (regardless of output label). A node on a cycle reaches itself.
  bool reaches(String from, String to) => _reachableFrom(from).contains(to);

  Set<String> _reachableFrom(String from) {
    final cached = _reachable[from];
    if (cached != null) return cached;

    final seen = <String>{};
    final stack = <String>[from];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final edge in outgoing(current)) {
        if (seen.add(edge.targetNodeId)) stack.add(edge.targetNodeId);
      }
    }
    return _reachable[from] = seen;
  }
}
