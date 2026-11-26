import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A resizable two-pane split with a draggable, keyboard-accessible handle.
///
/// Places [first] and [second] along [axis] separated by a `space2` gap with a
/// centered `space6` interactive hit band. The widget is uncontrolled:
/// [initialPosition] is copied into state on mount and subsequent changes to it
/// are ignored (give a new key to reset). Needs bounded constraints on both
/// axes.
class HiveSplitter extends StatefulWidget {
  /// Creates an uncontrolled two-pane splitter.
  const new({
    required this.first,
    required this.second,
    required this.initialPosition,
    required this.semanticLabel,
    this.onChanged,
    this.axis = Axis.horizontal,
    this.minFirst,
    this.minSecond,
    this.statesController,
    super.key,
  }) : assert(
         initialPosition >= 0 && initialPosition <= 1,
         'initialPosition must be between 0 and 1',
       );

  /// The leading pane (left on horizontal, top on vertical).
  final Widget first;

  /// The trailing pane (right on horizontal, bottom on vertical).
  final Widget second;

  /// Initial fraction (`0..1`) of the available main-axis extent given to
  /// [first]. Copied once in `initState`.
  final double initialPosition;

  /// Label announced by screen readers for the slider handle.
  final String semanticLabel;

  /// Called with the updated fraction (`0..1`) when the user drags or nudges
  /// the handle.
  final ValueChanged<double>? onChanged;

  /// Split direction; defaults to [Axis.horizontal] (side by side).
  final Axis axis;

  /// Minimum main-axis extent of [first] in logical pixels; defaults to
  /// `space8 * 4` (256).
  final double? minFirst;

  /// Minimum main-axis extent of [second] in logical pixels; defaults to
  /// `space8 * 4` (256).
  final double? minSecond;

  /// Optional external controller for handle interaction states.
  final WidgetStatesController? statesController;

  @override
  State<HiveSplitter> createState() => _HiveSplitterState();
}

class _HiveSplitterState extends State<HiveSplitter> {
  late double _fraction;
  WidgetStatesController? _ownController;

  WidgetStatesController get _controller =>
      widget.statesController ?? (_ownController ??= WidgetStatesController());

  @override
  void initState() {
    super.initState();
    _fraction = widget.initialPosition;
    _controller.addListener(_onStatesChanged);
  }

  @override
  void didUpdateWidget(HiveSplitter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _ownController)?.removeListener(
        _onStatesChanged,
      );
      _controller.addListener(_onStatesChanged);
    }
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

  void _applyExtent(
    double targetExtent, {
    required double available,
    required double minFirst,
    required double minSecond,
  }) {
    if (available <= 0) return;
    final hi = available - minSecond;
    if (hi < minFirst) return;
    final clamped = targetExtent.clamp(minFirst, hi);
    final nextFraction = clamped / available;
    if (nextFraction == _fraction) return;
    setState(() => _fraction = nextFraction);
    widget.onChanged?.call(nextFraction);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final radii = context.hiveRadii;
    final gap = spacing.space2;
    final bandThickness = spacing.space6;
    final step = spacing.space2;
    final defaultMin = spacing.space8 * 4;
    final minFirst = widget.minFirst ?? defaultMin;
    final minSecond = widget.minSecond ?? defaultMin;
    final horizontal = widget.axis == Axis.horizontal;

    final states = _controller.value;
    final Color gripColor;
    if (states.contains(WidgetState.pressed)) {
      gripColor = colors.onSurface;
    } else if (states.contains(WidgetState.hovered)) {
      gripColor = colors.onSurfaceMuted;
    } else {
      gripColor = colors.borderStrong;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mainExtent = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final available = mainExtent - gap;
        final extent = _effectiveFirstExtent(
          available: available,
          fraction: _fraction,
          minFirst: minFirst,
          minSecond: minSecond,
        );
        final bandStart = extent + (gap - bandThickness) / 2;

        final firstPane = FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: FocusTraversalGroup(child: widget.first),
        );
        final secondPane = FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: FocusTraversalGroup(child: widget.second),
        );

        final increasedExtent = _clampedTarget(
          extent + step,
          current: extent,
          available: available,
          minFirst: minFirst,
          minSecond: minSecond,
        );
        final decreasedExtent = _clampedTarget(
          extent - step,
          current: extent,
          available: available,
          minFirst: minFirst,
          minSecond: minSecond,
        );

        final handleBand = FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: Semantics(
            slider: true,
            focusable: true,
            focused: states.contains(WidgetState.focused),
            label: widget.semanticLabel,
            value: '${_percent(extent, available)}%',
            increasedValue: '${_percent(increasedExtent, available)}%',
            decreasedValue: '${_percent(decreasedExtent, available)}%',
            onIncrease: () => _applyExtent(
              extent + step,
              available: available,
              minFirst: minFirst,
              minSecond: minSecond,
            ),
            onDecrease: () => _applyExtent(
              extent - step,
              available: available,
              minFirst: minFirst,
              minSecond: minSecond,
            ),
            child: ExcludeSemantics(
              child: FocusableActionDetector(
                mouseCursor: horizontal
                    ? SystemMouseCursors.resizeColumn
                    : SystemMouseCursors.resizeRow,
                shortcuts: horizontal
                    ? const <ShortcutActivator, Intent>{
                        SingleActivator(LogicalKeyboardKey.arrowRight):
                            _NudgeIntent(1),
                        SingleActivator(LogicalKeyboardKey.arrowLeft):
                            _NudgeIntent(-1),
                      }
                    : const <ShortcutActivator, Intent>{
                        SingleActivator(LogicalKeyboardKey.arrowDown):
                            _NudgeIntent(1),
                        SingleActivator(LogicalKeyboardKey.arrowUp):
                            _NudgeIntent(-1),
                      },
                actions: <Type, Action<Intent>>{
                  _NudgeIntent: CallbackAction<_NudgeIntent>(
                    onInvoke: (intent) {
                      _applyExtent(
                        extent + intent.sign * step,
                        available: available,
                        minFirst: minFirst,
                        minSecond: minSecond,
                      );
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
                  onHorizontalDragStart: horizontal
                      ? (_) => _controller.update(WidgetState.pressed, true)
                      : null,
                  onHorizontalDragUpdate: horizontal
                      ? (details) => _applyExtent(
                          extent + (details.primaryDelta ?? 0),
                          available: available,
                          minFirst: minFirst,
                          minSecond: minSecond,
                        )
                      : null,
                  onHorizontalDragEnd: horizontal
                      ? (_) => _controller.update(WidgetState.pressed, false)
                      : null,
                  onHorizontalDragCancel: horizontal
                      ? () => _controller.update(WidgetState.pressed, false)
                      : null,
                  onVerticalDragStart: horizontal
                      ? null
                      : (_) => _controller.update(WidgetState.pressed, true),
                  onVerticalDragUpdate: horizontal
                      ? null
                      : (details) => _applyExtent(
                          extent + (details.primaryDelta ?? 0),
                          available: available,
                          minFirst: minFirst,
                          minSecond: minSecond,
                        ),
                  onVerticalDragEnd: horizontal
                      ? null
                      : (_) => _controller.update(WidgetState.pressed, false),
                  onVerticalDragCancel: horizontal
                      ? null
                      : () => _controller.update(WidgetState.pressed, false),
                  child: Center(
                    child: HiveFocusRing(
                      focused: states.contains(WidgetState.focused),
                      shape: const StadiumBorder(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: gripColor,
                          borderRadius: radii.pill,
                        ),
                        child: SizedBox(
                          width: horizontal ? spacing.space1 : spacing.space5,
                          height: horizontal ? spacing.space5 : spacing.space1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (horizontal) ...<Widget>[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: extent,
                  child: firstPane,
                ),
                Positioned(
                  left: extent + gap,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: secondPane,
                ),
                Positioned(
                  left: bandStart,
                  top: 0,
                  bottom: 0,
                  width: bandThickness,
                  child: handleBand,
                ),
              ] else ...<Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: extent,
                  child: firstPane,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: extent + gap,
                  bottom: 0,
                  child: secondPane,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: bandStart,
                  height: bandThickness,
                  child: handleBand,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NudgeIntent extends Intent {
  const new(this.sign);

  final int sign;
}

double _effectiveFirstExtent({
  required double available,
  required double fraction,
  required double minFirst,
  required double minSecond,
}) {
  if (available <= 0) return 0;
  final hi = available - minSecond;
  if (hi >= minFirst) {
    return (fraction * available).clamp(minFirst, hi);
  }
  final totalMin = minFirst + minSecond;
  if (totalMin <= 0) return available * fraction;
  return available * minFirst / totalMin;
}

double _clampedTarget(
  double target, {
  required double current,
  required double available,
  required double minFirst,
  required double minSecond,
}) {
  if (available <= 0) return 0;
  final hi = available - minSecond;
  if (hi < minFirst) return current;
  return target.clamp(minFirst, hi);
}

int _percent(double extent, double available) {
  if (available <= 0) return 0;
  return (extent / available * 100).round();
}
