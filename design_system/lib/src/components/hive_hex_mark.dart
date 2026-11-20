import 'dart:math' as math;

import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The Agentic Hive brand mark: a lime hexagon with an inner hexagon cell.
///
/// The brand mark is the hexagon; never a sparkle or an emoji.
class HiveHexMark extends StatelessWidget {
  /// Creates the mark.
  const new({required this.semanticLabel, this.size, super.key});

  /// Accessibility label, for example the product name.
  final String semanticLabel;

  /// Logical size; defaults to `space5`.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final dimension = size ?? context.hiveSpacing.space5;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox.square(
        dimension: dimension,
        child: CustomPaint(
          painter: _HexMarkPainter(fill: colors.accent, cell: colors.onAccent),
        ),
      ),
    );
  }
}

class _HexMarkPainter extends CustomPainter {
  const new({required this.fill, required this.cell});

  final Color fill;
  final Color cell;

  static Path _hexagon(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 90);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas
      ..drawPath(
        _hexagon(center, radius),
        Paint()
          ..color = fill
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        _hexagon(center, radius * 0.42),
        Paint()
          ..color = cell
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = radius * 0.14,
      );
  }

  @override
  bool shouldRepaint(_HexMarkPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.cell != cell;
  }
}
