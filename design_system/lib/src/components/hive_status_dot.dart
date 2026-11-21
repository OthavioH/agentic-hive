import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:design_system/src/visuals/hive_status.dart';
import 'package:material_ui/material_ui.dart';

/// A node status glyph: a distinct shape plus a color per status, so status
/// never depends on color alone.
///
/// Statuses whose shape is animated (such as [HiveNodeStatus.cancelling])
/// loop a slow, subtle transition, and show their still frame when
/// `MediaQuery.disableAnimations` is set.
class HiveStatusDot extends StatefulWidget {
  /// Creates a status glyph for [status].
  const new({
    required this.status,
    required this.semanticLabel,
    this.size,
    super.key,
  });

  /// The status to show.
  final HiveNodeStatus status;

  /// Localized status name announced by screen readers.
  final String semanticLabel;

  /// Logical size; defaults to `space2`.
  final double? size;

  @override
  State<HiveStatusDot> createState() => _HiveStatusDotState();
}

// Not the single-ticker mixin: the controller is recreated when the status or
// the reduced-motion setting changes.
class _HiveStatusDotState extends State<HiveStatusDot>
    with TickerProviderStateMixin {
  AnimationController? _controller;

  bool get _animates =>
      widget.status.shape.isAnimated &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(HiveStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _syncController();
  }

  void _syncController() {
    if (!_animates) {
      _controller?.dispose();
      _controller = null;
      return;
    }
    // One turn every three `long` periods, like `HiveSpinner`: calm, not
    // frantic.
    final controller = (_controller ??= AnimationController(vsync: this))
      ..duration = context.hiveMotion.long * 3;
    if (!controller.isAnimating) controller.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size ?? context.hiveSpacing.space2,
        child: CustomPaint(
          painter: HiveStatusShapePainter(
            shape: widget.status.shape,
            color: widget.status.color(context.hiveColors),
            animation: _controller,
          ),
        ),
      ),
    );
  }
}
