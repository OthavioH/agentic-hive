import 'dart:math' as math;

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Shared geometry constants for workflow canvas nodes and ports.
abstract final class WorkflowCanvasGeometry {
  /// Logical width of a node card on the canvas.
  static const double nodeWidth = 224;

  /// Logical height of a node card on the canvas.
  static const double nodeHeight = 88;

  /// Canvas width.
  static const double canvasWidth = 3200;

  /// Canvas height.
  static const double canvasHeight = 2400;

  /// Grid spacing in logical pixels.
  static const double gridStep = 32;

  /// Hit-test distance threshold for selecting an edge.
  static const double edgeHitThreshold = 14;

  /// Center of the left-side input port for [node].
  static Offset inputPortCenter(WorkflowNode node) =>
      Offset(node.position.x, node.position.y + nodeHeight / 2);

  /// Center of the right-side output port for [node].
  static Offset outputPortCenter(WorkflowNode node) =>
      Offset(node.position.x + nodeWidth, node.position.y + nodeHeight / 2);

  /// Computes the Bezier [Path] and midpoint for an edge between [source] and
  /// [target].
  static ({Path path, Offset midpoint, Offset endTangent}) buildEdgePath(
    WorkflowNode source,
    WorkflowNode target,
  ) {
    if (source.id == target.id) {
      final start = outputPortCenter(source);
      final end = inputPortCenter(target);
      final loopTop = source.position.y - 56;
      final c1 = Offset(start.dx + 64, loopTop);
      final c2 = Offset(end.dx - 64, loopTop);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      final mid = _cubicPoint(start, c1, c2, end, 0.5);
      return (path: path, midpoint: mid, endTangent: end - c2);
    }

    final start = outputPortCenter(source);
    final end = inputPortCenter(target);
    final dx = math.max((end.dx - start.dx).abs() * 0.5, 64);
    final c1 = Offset(start.dx + dx, start.dy);
    final c2 = Offset(end.dx - dx, end.dy);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    final mid = _cubicPoint(start, c1, c2, end, 0.5);
    return (path: path, midpoint: mid, endTangent: end - c2);
  }

  /// Hit-tests [point] against all edges, returning the matching edge ID or
  /// `null`.
  static String? hitTestEdge({
    required Offset point,
    required List<WorkflowNode> nodes,
    required List<WorkflowEdge> edges,
  }) {
    final nodeMap = <String, WorkflowNode>{
      for (final node in nodes) node.id: node,
    };

    for (final edge in edges.reversed) {
      final source = nodeMap[edge.sourceNodeId];
      final target = nodeMap[edge.targetNodeId];
      if (source == null || target == null) continue;

      final edgePath = buildEdgePath(source, target);
      if ((point - edgePath.midpoint).distance <= edgeHitThreshold * 2) {
        return edge.id;
      }
      for (final metric in edgePath.path.computeMetrics()) {
        const samples = 24;
        for (var i = 0; i <= samples; i++) {
          final tangent = metric.getTangentForOffset(
            metric.length * (i / samples),
          );
          if (tangent != null &&
              (point - tangent.position).distance <= edgeHitThreshold) {
            return edge.id;
          }
        }
      }
    }
    return null;
  }

  static Offset _cubicPoint(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;
    return p0 * uuu + p1 * (3 * uu * t) + p2 * (3 * u * tt) + p3 * ttt;
  }
}

/// Paints a subtle dot grid on the workflow graph canvas.
final class WorkflowGridPainter extends CustomPainter {
  /// Creates a [WorkflowGridPainter].
  const new({required this.dotColor});

  /// Color of the grid dots.
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    const step = WorkflowCanvasGeometry.gridStep;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.25, paint);
      }
    }
  }

  @override
  bool shouldRepaint(WorkflowGridPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}

/// Paints all directed edges, edge labels, selection highlights, and an
/// optional in-progress connection preview curve.
final class WorkflowEdgesPainter extends CustomPainter {
  /// Creates a [WorkflowEdgesPainter].
  const new({
    required this.nodes,
    required this.edges,
    required this.selectedEdgeId,
    required this.errorEdgeIds,
    required this.warningEdgeIds,
    required this.colors,
    required this.typography,
    required this.flowPhase,
    this.draftStart,
    this.draftEnd,
  });

  /// Current workflow nodes.
  final List<WorkflowNode> nodes;

  /// Current workflow edges.
  final List<WorkflowEdge> edges;

  /// Currently selected edge ID, if any.
  final String? selectedEdgeId;

  /// Edge IDs with error-severity validation issues.
  final Set<String> errorEdgeIds;

  /// Edge IDs with warning-severity validation issues.
  final Set<String> warningEdgeIds;

  /// Design system color tokens.
  final HiveColors colors;

  /// Design system typography tokens.
  final HiveTypography typography;

  /// Normalized `0..1` animation phase for selected-edge flow pulse.
  final double flowPhase;

  /// Start coordinate of an in-progress edge drag, if any.
  final Offset? draftStart;

  /// End coordinate of an in-progress edge drag, if any.
  final Offset? draftEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = <String, WorkflowNode>{
      for (final node in nodes) node.id: node,
    };

    for (final edge in edges) {
      final source = nodeMap[edge.sourceNodeId];
      final target = nodeMap[edge.targetNodeId];
      if (source == null || target == null) continue;

      final isSelected = edge.id == selectedEdgeId;
      final hasError = errorEdgeIds.contains(edge.id);
      final hasWarning = warningEdgeIds.contains(edge.id);

      final strokeColor = isSelected
          ? colors.accent
          : hasError
          ? colors.danger
          : hasWarning
          ? colors.warning
          : colors.onSurfaceMuted;

      final geometry = WorkflowCanvasGeometry.buildEdgePath(source, target);
      final paint = Paint()
        ..color = strokeColor
        ..strokeWidth = isSelected ? 2.5 : 1.75
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(geometry.path, paint);

      if (isSelected) {
        _paintFlowPulse(canvas, geometry.path, strokeColor);
      }

      final targetPoint = WorkflowCanvasGeometry.inputPortCenter(target);
      _paintArrowhead(canvas, targetPoint, geometry.endTangent, strokeColor);
      _paintEdgeLabel(canvas, edge, geometry.midpoint, strokeColor, isSelected);
    }

    if (draftStart != null && draftEnd != null) {
      final start = draftStart!;
      final end = draftEnd!;
      final dx = math.max((end.dx - start.dx).abs() * 0.5, 48);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx + dx, start.dy, end.dx - dx, end.dy, end.dx, end.dy);
      final draftPaint = Paint()
        ..color = colors.accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, draftPaint);
      _paintArrowhead(
        canvas,
        end,
        end - Offset(end.dx - dx, end.dy),
        colors.accent,
      );
    }
  }

  void _paintFlowPulse(Canvas canvas, Path path, Color color) {
    for (final metric in path.computeMetrics()) {
      if (metric.length <= 0) continue;
      final tangent = metric.getTangentForOffset(metric.length * flowPhase);
      if (tangent == null) continue;
      final pulsePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tangent.position, 4, pulsePaint);
    }
  }

  void _paintArrowhead(Canvas canvas, Offset tip, Offset tangent, Color color) {
    final angle = tangent.distance == 0 ? 0.0 : tangent.direction;
    const arrowLength = 9.0;
    const arrowSpread = 0.45;
    final p1 =
        tip -
        Offset(
          math.cos(angle - arrowSpread) * arrowLength,
          math.sin(angle - arrowSpread) * arrowLength,
        );
    final p2 =
        tip -
        Offset(
          math.cos(angle + arrowSpread) * arrowLength,
          math.sin(angle + arrowSpread) * arrowLength,
        );
    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _paintEdgeLabel(
    Canvas canvas,
    WorkflowEdge edge,
    Offset midpoint,
    Color borderColor,
    bool isSelected,
  ) {
    final retrySuffix = edge.maxRetries != null ? ' ×${edge.maxRetries}' : '';
    final labelText = '${edge.sourceOutput}$retrySuffix';
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: typography.label.copyWith(
          color: isSelected ? colors.accent : colors.onSurface,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    const hPad = 8.0;
    const vPad = 4.0;
    final rect = Rect.fromCenter(
      center: midpoint,
      width: textPainter.width + hPad * 2,
      height: textPainter.height + vPad * 2,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );

    canvas
      ..drawRRect(
        rrect,
        Paint()
          ..color = colors.surface2
          ..style = PaintingStyle.fill,
      )
      ..drawRRect(
        rrect,
        Paint()
          ..color = isSelected
              ? colors.accent
              : borderColor.withValues(alpha: 0.6)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );

    textPainter.paint(canvas, Offset(rect.left + hPad, rect.top + vPad));
  }

  @override
  bool shouldRepaint(WorkflowEdgesPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.selectedEdgeId != selectedEdgeId ||
        oldDelegate.flowPhase != flowPhase ||
        oldDelegate.draftStart != draftStart ||
        oldDelegate.draftEnd != draftEnd ||
        oldDelegate.colors != colors;
  }
}
