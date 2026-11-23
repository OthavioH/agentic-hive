import 'dart:math' as math;

import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A small rotating arc used by loading and connecting states.
///
/// Shows a still arc when `MediaQuery.disableAnimations` is set.
class HiveSpinner extends StatefulWidget {
  /// Creates a spinner of [size] in [color].
  const new({required this.size, required this.color, super.key});

  /// Logical size.
  final double size;

  /// Arc color.
  final Color color;

  @override
  State<HiveSpinner> createState() => _HiveSpinnerState();
}

class _HiveSpinnerState extends State<HiveSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.hiveMotion;
    // One turn every three `long` periods reads as calm, not frantic.
    _controller.duration = motion.long * 3;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(painter: _ArcPainter(color: widget.color)),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const new({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.14;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}
