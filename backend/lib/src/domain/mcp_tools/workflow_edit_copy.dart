import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Counts of what an `edit_workflow` call changed (B10).
final class WorkflowEditTally {
  /// Number of nodes added.
  int nodesAdded = 0;

  /// Number of added nodes assigned an automatic position.
  int autoPlaced = 0;

  /// Number of node update operations.
  int nodesUpdated = 0;

  /// Number of nodes removed.
  int nodesRemoved = 0;

  /// Number of edges added.
  int edgesAdded = 0;

  /// Number of edges removed.
  int edgesRemoved = 0;

  /// Last entry node selected, if any.
  String? entrySet;

  /// Whether metadata was changed.
  bool metaChanged = false;

  /// The B10 parts joined by `, `, omitting zero counts.
  String describe() {
    final placed = autoPlaced > 0 ? ' ($autoPlaced auto-placed)' : '';
    return <String>[
      if (nodesAdded > 0) '$nodesAdded nodes added$placed',
      if (nodesUpdated > 0) '$nodesUpdated nodes updated',
      if (nodesRemoved > 0) '$nodesRemoved nodes removed',
      if (edgesAdded > 0) '$edgesAdded edges added',
      if (edgesRemoved > 0) '$edgesRemoved edges removed',
      if (entrySet case final id?) 'entry set to $id',
      if (metaChanged) 'name or description changed',
    ].join(', ');
  }
}

/// Mutable in-memory copy of a workflow that edit operations change (B4).
final class WorkflowEditCopy {
  /// Copies [workflow]; the next edge number follows O4e.
  new of(Workflow workflow)
    : name = workflow.name,
      description = workflow.description,
      entryNodeId = workflow.entryNodeId,
      nodes = [...workflow.nodes],
      edges = [...workflow.edges],
      _nextEdge = _followingEdgeNumber(workflow.edges);

  static int _followingEdgeNumber(List<WorkflowEdge> edges) {
    var largest = 0;
    final pattern = RegExp(r'^edge_(\d+)$');
    for (final edge in edges) {
      final match = pattern.firstMatch(edge.id);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (number > largest) largest = number;
      }
    }
    return largest + 1;
  }

  /// Workflow name.
  String name;

  /// Optional workflow description.
  String? description;

  /// Entry node id.
  String? entryNodeId;

  /// Mutable ordered copy of workflow nodes.
  final List<WorkflowNode> nodes;

  /// Mutable ordered copy of workflow edges.
  final List<WorkflowEdge> edges;

  /// Ids of added nodes that require auto-layout.
  final Set<String> autoPlace = <String>{};

  /// Operation counts for the response.
  final WorkflowEditTally tally = WorkflowEditTally();

  int _nextEdge;

  /// Index of node [id] in [nodes], or -1.
  int indexOfNode(String id) => nodes.indexWhere((node) => node.id == id);

  /// Whether a node [id] exists.
  bool hasNode(String id) => indexOfNode(id) >= 0;

  /// Returns `edge_<k>` and advances k (O4e).
  String nextEdgeId() => 'edge_${_nextEdge++}';
}
