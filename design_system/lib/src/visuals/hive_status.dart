import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:material_ui/material_ui.dart';

/// A status glyph shape. Status is shown by shape and color, never color
/// alone, so each status owns a distinct shape.
abstract class HiveStatusShape {
  /// Const constructor for subclasses.
  const new();

  /// Paints the shape filling [rect] in [color].
  void paint(Canvas canvas, Rect rect, Color color);
}

/// Hollow ring.
class HiveRingShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    final stroke = rect.shortestSide * 0.22;
    canvas.drawCircle(
      rect.center,
      (rect.shortestSide - stroke) / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }
}

/// Filled circle.
class HiveDiscShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    canvas.drawCircle(
      rect.center,
      rect.shortestSide / 2,
      Paint()..color = color,
    );
  }
}

/// Filled right-pointing triangle with rounded joins ("playing").
class HiveTriangleShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    final s = rect.shortestSide;
    final r = Rect.fromCenter(center: rect.center, width: s, height: s);
    final path = Path()
      ..moveTo(r.left + s * 0.14, r.top + s * 0.06)
      ..lineTo(r.right - s * 0.02, r.center.dy)
      ..lineTo(r.left + s * 0.14, r.bottom - s * 0.06)
      ..close();
    // Fill plus a round-joined stroke of the same color rounds the corners.
    final paint = Paint()
      ..color = color
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.12;
    canvas
      ..drawPath(path, paint)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = s * 0.12
          ..style = PaintingStyle.stroke,
      );
  }
}

/// Two rounded vertical bars ("paused").
class HivePauseShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    final s = rect.shortestSide;
    final barWidth = s * 0.34;
    final radius = Radius.circular(barWidth / 2);
    final top = rect.center.dy - s / 2;
    final paint = Paint()..color = color;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.center.dx - s / 2, top, barWidth, s),
          radius,
        ),
        paint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.center.dx + s / 2 - barWidth, top, barWidth, s),
          radius,
        ),
        paint,
      );
  }
}

/// Filled diamond ("failed").
class HiveDiamondShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    final h = rect.shortestSide / 2;
    final c = rect.center;
    final path = Path()
      ..moveTo(c.dx, c.dy - h)
      ..lineTo(c.dx + h, c.dy)
      ..lineTo(c.dx, c.dy + h)
      ..lineTo(c.dx - h, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
}

/// Node status as shown by `HiveStatusDot` and `HiveAgentAvatar`.
enum HiveNodeStatus {
  /// Not started: hollow ring in `statusIdle`.
  idle(HiveRingShape(), _idle),

  /// Running: triangle in `statusRunning`.
  running(HiveTriangleShape(), _running),

  /// Paused or waiting for a human: two bars in `statusPaused`.
  paused(HivePauseShape(), _paused),

  /// Failed: diamond in `statusFailed`.
  failed(HiveDiamondShape(), _failed),

  /// Succeeded: filled circle in `statusSucceeded`.
  succeeded(HiveDiscShape(), _succeeded);

  new(this.shape, this.color);

  /// The distinct shape of this status.
  final HiveStatusShape shape;

  /// The color role of this status.
  final HiveColorRole color;
}

Color _idle(HiveColors c) => c.statusIdle;
Color _running(HiveColors c) => c.statusRunning;
Color _paused(HiveColors c) => c.statusPaused;
Color _failed(HiveColors c) => c.statusFailed;
Color _succeeded(HiveColors c) => c.statusSucceeded;

/// Paints a [HiveStatusShape].
class HiveStatusShapePainter extends CustomPainter {
  /// Creates a painter for [shape] in [color].
  const new({required this.shape, required this.color});

  /// The shape to paint.
  final HiveStatusShape shape;

  /// The fill or stroke color.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    shape.paint(canvas, Offset.zero & size, color);
  }

  @override
  bool shouldRepaint(HiveStatusShapePainter oldDelegate) {
    return oldDelegate.shape != shape || oldDelegate.color != color;
  }
}
