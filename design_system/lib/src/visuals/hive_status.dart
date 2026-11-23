import 'dart:math' as math;

import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:material_ui/material_ui.dart';

/// A status glyph shape. Status is shown by shape and color, never color
/// alone, so each status owns a distinct shape.
abstract class HiveStatusShape {
  /// Const constructor for subclasses.
  const new();

  /// Paints the shape filling [rect] in [color].
  void paint(Canvas canvas, Rect rect, Color color);

  /// Whether the shape has a looping transition (see [paintFrame]).
  ///
  /// Animated shapes must stay legible on their still frame, because
  /// `HiveStatusDot` paints only frame `0` when
  /// `MediaQuery.disableAnimations` is set.
  bool get isAnimated => false;

  /// Paints the frame at [progress] (from 0 to 1) of the looping transition.
  ///
  /// Still shapes ignore [progress] and paint [paint].
  void paintFrame(Canvas canvas, Rect rect, Color color, double progress) {
    paint(canvas, rect, color);
  }
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

/// Hollow ring with its left half filled ("interrupted": stopped part-way).
class HiveHalfDiscShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    final s = rect.shortestSide;
    final stroke = s * 0.18;
    final outer = Rect.fromCenter(center: rect.center, width: s, height: s);
    canvas
      ..drawCircle(
        rect.center,
        (s - stroke) / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      )
      ..drawArc(outer, math.pi / 2, math.pi, true, Paint()..color = color);
  }
}

/// Two crossed rounded bars ("cancelled").
class HiveCrossShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    final s = rect.shortestSide;
    final stroke = s * 0.26;
    // Inset by half the stroke so the round caps stay inside [rect].
    final inset = Rect.fromCenter(
      center: rect.center,
      width: s - stroke,
      height: s - stroke,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas
      ..drawLine(inset.topLeft, inset.bottomRight, paint)
      ..drawLine(inset.topRight, inset.bottomLeft, paint);
  }
}

/// Open ring with a rounded stop square inside ("cancelling": a stop was
/// requested and the process tree is still exiting).
///
/// The ring's gap turns slowly while animations are enabled.
class HiveStopRingShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  bool get isAnimated => true;

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    paintFrame(canvas, rect, color, 0);
  }

  @override
  void paintFrame(Canvas canvas, Rect rect, Color color, double progress) {
    final s = rect.shortestSide;
    final stroke = s * 0.16;
    final ring = Rect.fromCenter(
      center: rect.center,
      width: s - stroke,
      height: s - stroke,
    );
    final square = s * 0.36;
    canvas
      ..drawArc(
        ring,
        -math.pi / 2 + progress * 2 * math.pi,
        math.pi * 1.5,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: rect.center, width: square, height: square),
          Radius.circular(square * 0.25),
        ),
        Paint()..color = color,
      );
  }
}

/// Hollow up-pointing triangle with an exclamation mark ("cancellation
/// uncertain": the stop could not be confirmed and processes may still run).
class HiveAlertTriangleShape extends HiveStatusShape {
  /// Creates the shape.
  const new();

  @override
  void paint(Canvas canvas, Rect rect, Color color) {
    final s = rect.shortestSide;
    final stroke = s * 0.13;
    final r = Rect.fromCenter(
      center: rect.center,
      width: s - stroke,
      height: s - stroke,
    );
    final outline = Path()
      ..moveTo(r.center.dx, r.top)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..close();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas
      ..drawPath(outline, paint)
      ..drawLine(
        Offset(r.center.dx, r.top + r.height * 0.4),
        Offset(r.center.dx, r.top + r.height * 0.66),
        paint,
      )
      ..drawCircle(
        Offset(r.center.dx, r.top + r.height * 0.84),
        stroke * 0.6,
        Paint()..color = color,
      );
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
  succeeded(HiveDiscShape(), _succeeded),

  /// Interrupted (the backend stopped mid-run, e.g. a crash or restart):
  /// half-filled ring in `warning`.
  interrupted(HiveHalfDiscShape(), _interrupted),

  /// Cancelled by the user: cross in `statusIdle`.
  cancelled(HiveCrossShape(), _cancelled),

  /// Cancel requested, waiting for the process tree to exit: open ring with
  /// a stop square in `warning`, its gap turning slowly unless
  /// `MediaQuery.disableAnimations` is set.
  cancelling(HiveStopRingShape(), _cancelling),

  /// The backend could not confirm the process tree exited: hollow alert
  /// triangle in `danger`.
  cancellationUncertain(HiveAlertTriangleShape(), _cancellationUncertain);

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
Color _interrupted(HiveColors c) => c.warning;
Color _cancelled(HiveColors c) => c.statusIdle;
Color _cancelling(HiveColors c) => c.warning;
Color _cancellationUncertain(HiveColors c) => c.danger;

/// Paints a [HiveStatusShape].
class HiveStatusShapePainter extends CustomPainter {
  /// Creates a painter for [shape] in [color].
  ///
  /// Pass [animation] to paint the frame at its value and repaint whenever it
  /// ticks; without it the still frame `0` is painted.
  const new({required this.shape, required this.color, this.animation})
    : super(repaint: animation);

  /// The shape to paint.
  final HiveStatusShape shape;

  /// The fill or stroke color.
  final Color color;

  /// Drives [HiveStatusShape.paintFrame]; null paints the still frame.
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    shape.paintFrame(canvas, Offset.zero & size, color, animation?.value ?? 0);
  }

  @override
  bool shouldRepaint(HiveStatusShapePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.animation != animation;
  }
}
