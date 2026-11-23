import 'dart:collection';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// A node to lay out: its id and its given position, if any.
final class AutoLayoutNode {
  /// Creates a node for automatic layout.
  const new({required this.id, this.position});

  /// Node identifier.
  final String id;

  /// Existing position, preserved by the layout.
  final WorkflowPosition? position;
}

/// Places nodes in left-to-right layers without overlapping any node.
final class WorkflowAutoLayout {
  /// Creates a layout engine.
  const new();

  /// First column x coordinate.
  static const double originX = 120;

  /// First row y coordinate.
  static const double originY = 120;

  /// Editor node width.
  static const double nodeWidth = 224;

  /// Editor node height.
  static const double nodeHeight = 88;

  /// Horizontal distance between layer origins.
  static const double columnStep = 320;

  /// Vertical distance between row origins.
  static const double rowStep = 160;

  /// Clearance between node rectangles.
  static const double minGap = 24;

  /// Returns a position for every node, preserving explicitly given positions.
  Map<String, WorkflowPosition> layout({
    required List<AutoLayoutNode> nodes,
    required List<({String from, String to})> edges,
    String? entryNodeId,
  }) {
    final byId = <String, AutoLayoutNode>{
      for (final node in nodes) node.id: node,
    };
    final adjacency = <String, List<String>>{
      for (final node in nodes) node.id: <String>[],
    };
    for (final edge in edges) {
      if (adjacency.containsKey(edge.from) && adjacency.containsKey(edge.to)) {
        adjacency[edge.from]!.add(edge.to);
      }
    }
    final layers = <String, int>{};
    final layerOrder = <int, List<String>>{};
    final seeds = <String>[
      if (entryNodeId != null && byId.containsKey(entryNodeId)) entryNodeId,
      for (final node in nodes)
        if (node.id != entryNodeId) node.id,
    ];
    for (final seed in seeds) {
      if (layers.containsKey(seed)) continue;
      final queue = Queue<String>()..add(seed);
      layers[seed] = 0;
      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        final depth = layers[current]!;
        (layerOrder[depth] ??= <String>[]).add(current);
        for (final neighbor in adjacency[current]!) {
          if (layers.containsKey(neighbor)) continue;
          layers[neighbor] = depth + 1;
          queue.add(neighbor);
        }
      }
    }

    final positions = <String, WorkflowPosition>{};
    final occupied = <WorkflowPosition>[];
    for (final node in nodes) {
      final position = node.position;
      if (position != null) {
        positions[node.id] = position;
        occupied.add(position);
      }
    }
    final nextRow = <int, int>{};
    for (final depth in layerOrder.keys.toList()..sort()) {
      for (final id in layerOrder[depth]!) {
        final node = byId[id]!;
        if (node.position != null) continue;
        var row = nextRow[depth] ?? 0;
        final x = originX + depth * columnStep;
        var candidate = WorkflowPosition(x: x, y: originY + row * rowStep);
        while (occupied.any((other) => _conflicts(candidate, other))) {
          row++;
          candidate = WorkflowPosition(x: x, y: originY + row * rowStep);
        }
        positions[id] = candidate;
        occupied.add(candidate);
        nextRow[depth] = row + 1;
      }
    }
    return positions;
  }

  bool _conflicts(WorkflowPosition a, WorkflowPosition b) =>
      a.x < b.x + nodeWidth + minGap &&
      b.x < a.x + nodeWidth + minGap &&
      a.y < b.y + nodeHeight + minGap &&
      b.y < a.y + nodeHeight + minGap;
}
