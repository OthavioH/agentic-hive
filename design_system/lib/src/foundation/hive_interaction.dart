import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Builds an interactive component from its current [WidgetState]s.
typedef HiveStatesBuilder = Widget Function(
  BuildContext context,
  Set<WidgetState> states,
);

/// The interaction core of every interactive `Hive*` component.
///
/// Tracks hover, keyboard focus, press and disabled states in a
/// [WidgetStatesController], activates on tap, Enter and Space, shows a
/// click cursor, and exposes one semantics node labelled [semanticLabel].
///
/// Pass a [statesController] to show a state statically (Widgetbook, golden
/// tests) or to observe the states from outside.
class HiveInteraction extends StatefulWidget {
  /// Creates the interaction core.
  const new({
    required this.semanticLabel,
    required this.onPressed,
    required this.builder,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    this.selected,
    this.expanded,
    this.toggled,
    this.semanticValue,
    this.semanticHint,
    this.busy = false,
    super.key,
  });

  /// Label announced by screen readers.
  final String semanticLabel;

  /// Called on activation; null disables the component.
  final VoidCallback? onPressed;

  /// Builds the visuals for the current states.
  final HiveStatesBuilder builder;

  /// Optional external controller of the states.
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  /// Selection state for semantics (rail items), or null when not selectable.
  final bool? selected;

  /// Expansion state for semantics (disclosure headers), or null when the
  /// component does not expand.
  final bool? expanded;

  /// On/off state for semantics (switches), or null when not a toggle.
  ///
  /// When set, the node is announced as a toggle instead of a button.
  final bool? toggled;

  /// Current value announced after the label (a select's chosen option).
  final String? semanticValue;

  /// Extra description announced after the value (helper or error text).
  final String? semanticHint;

  /// Whether the component is busy (loading); it then ignores activation.
  final bool busy;

  @override
  State<HiveInteraction> createState() => _HiveInteractionState();
}

class _HiveInteractionState extends State<HiveInteraction> {
  WidgetStatesController? _ownController;

  WidgetStatesController get _controller =>
      widget.statesController ?? (_ownController ??= WidgetStatesController());

  bool get _enabled => widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _controller
      ..update(WidgetState.disabled, !_enabled)
      ..addListener(_onStatesChanged);
  }

  @override
  void didUpdateWidget(HiveInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _ownController)?.removeListener(
        _onStatesChanged,
      );
      _controller.addListener(_onStatesChanged);
    }
    _controller.update(WidgetState.disabled, !_enabled);
    if (!_enabled) _controller.update(WidgetState.pressed, false);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStatesChanged);
    _ownController?.dispose();
    super.dispose();
  }

  void _onStatesChanged() {
    if (mounted) setState(() {});
  }

  void _activate() {
    if (!_enabled || widget.busy) return;
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = _enabled && !widget.busy;
    return Semantics(
      button: widget.toggled == null,
      enabled: _enabled,
      selected: widget.selected,
      expanded: widget.expanded,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      value: widget.semanticValue,
      hint: widget.semanticHint,
      onTap: interactive ? _activate : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: _enabled,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          mouseCursor: interactive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          onShowHoverHighlight: (value) =>
              _controller.update(WidgetState.hovered, value),
          onShowFocusHighlight: (value) =>
              _controller.update(WidgetState.focused, value),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: interactive
                ? (_) => _controller.update(WidgetState.pressed, true)
                : null,
            onTapUp: interactive
                ? (_) => _controller.update(WidgetState.pressed, false)
                : null,
            onTapCancel: interactive
                ? () => _controller.update(WidgetState.pressed, false)
                : null,
            onTap: interactive ? _activate : null,
            child: widget.builder(context, _controller.value),
          ),
        ),
      ),
    );
  }
}

/// Composes the hover or pressed state layer of [foreground] over [base].
Color hiveStateLayer({
  required Color base,
  required Color foreground,
  required Set<WidgetState> states,
  required HiveColors colors,
}) {
  final double opacity;
  if (states.contains(WidgetState.disabled)) {
    opacity = 0;
  } else if (states.contains(WidgetState.pressed)) {
    opacity = colors.pressedOpacity;
  } else if (states.contains(WidgetState.hovered)) {
    opacity = colors.hoverOpacity;
  } else {
    opacity = 0;
  }
  if (opacity == 0) return base;
  return Color.alphaBlend(foreground.withValues(alpha: opacity), base);
}

/// Draws the keyboard focus ring outside [child] when [focused].
///
/// The ring follows [shape], sits one ring-width outside the child's bounds
/// and never changes layout.
class HiveFocusRing extends StatelessWidget {
  /// Creates a focus ring around [child].
  const new({
    required this.focused,
    required this.shape,
    required this.child,
    super.key,
  });

  /// Whether to draw the ring.
  final bool focused;

  /// The outline the ring follows.
  final ShapeBorder shape;

  /// The focused component.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Always wrap in the same widget so toggling focus never remounts
    // [child] (a remount would drop a text field's input connection).
    return CustomPaint(
      foregroundPainter: focused
          ? _FocusRingPainter(
              shape: shape,
              color: context.hiveColors.focusRing,
              width: context.hiveElevation.focusRingWidth,
            )
          : null,
      child: child,
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const new({required this.shape, required this.color, required this.width});

  final ShapeBorder shape;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(width * 1.5);
    canvas.drawPath(
      shape.getOuterPath(rect),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.width != width;
  }
}
