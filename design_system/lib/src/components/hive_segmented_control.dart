import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// One option of a [HiveSegmentedControl].
@immutable
class HiveSegment<T> {
  /// Creates a segment.
  const new({
    required this.value,
    required this.label,
    this.icon,
    this.semanticLabel,
  });

  /// The value reported when this segment is chosen.
  final T value;

  /// Visible text.
  final String label;

  /// Optional leading icon.
  final HiveIconData? icon;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;
}

/// A pill track of mutually exclusive options (for example Raw / Preview).
///
/// The selected segment uses the inverse `onSurface` fill with `background`
/// text; the others are `onSurfaceMuted` on the `surface3` track. Each
/// segment is focusable, activates with Enter or Space and announces its
/// selection.
class HiveSegmentedControl<T> extends StatelessWidget {
  /// Creates a segmented control. A null [onChanged] disables it.
  const new({
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    this.statesControllers,
    super.key,
  });

  /// The options, left to right; at least two.
  final List<HiveSegment<T>> segments;

  /// The selected value.
  final T selected;

  /// Called with the chosen value; null disables the control.
  final ValueChanged<T>? onChanged;

  /// Names the whole group for screen readers.
  final String semanticLabel;

  /// Optional external states per segment index, for static previews.
  final Map<int, WidgetStatesController>? statesControllers;

  @override
  Widget build(BuildContext context) {
    assert(segments.length >= 2, 'A segmented control needs 2+ options.');
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final change = onChanged;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Opacity(
        opacity: change == null ? colors.disabledOpacity : 1,
        child: Container(
          padding: EdgeInsets.all(spacing.spaceHalf),
          decoration: ShapeDecoration(
            color: colors.surface3,
            shape: StadiumBorder(
              side: BorderSide(
                color: colors.borderSubtle,
                width: context.hiveElevation.hairline,
              ),
            ),
          ),
          child: FocusTraversalGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < segments.length; i++)
                  _SegmentButton<T>(
                    segment: segments[i],
                    selected: segments[i].value == selected,
                    onPressed: change == null
                        ? null
                        : () => change(segments[i].value),
                    statesController: statesControllers?[i],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const new({
    required this.segment,
    required this.selected,
    required this.onPressed,
    required this.statesController,
  });

  final HiveSegment<T> segment;
  final bool selected;
  final VoidCallback? onPressed;
  final WidgetStatesController? statesController;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final foreground = selected ? colors.background : colors.onSurfaceMuted;
    final icon = segment.icon;
    return HiveInteraction(
      semanticLabel: segment.semanticLabel ?? segment.label,
      selected: selected,
      onPressed: onPressed,
      statesController: statesController,
      builder: (context, states) => HiveFocusRing(
        focused: states.contains(WidgetState.focused),
        shape: const StadiumBorder(),
        child: AnimatedContainer(
          duration: motion.resolve(context, motion.short),
          curve: motion.standardCurve,
          height: spacing.space4,
          padding: EdgeInsets.symmetric(horizontal: spacing.space2),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: hiveStateLayer(
              base: selected
                  ? colors.onSurface
                  : colors.surface3.withValues(alpha: 0),
              foreground: selected ? colors.background : colors.onSurface,
              states: states,
              colors: colors,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                HiveIcon(icon, size: spacing.space2, color: foreground),
                SizedBox(width: spacing.spaceHalf),
              ],
              Text(
                segment.label,
                maxLines: 1,
                style: context.hiveTypography.label.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
