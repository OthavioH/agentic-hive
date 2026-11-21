import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A pill toggle that turns one quick filter on or off (for example a run
/// status in the event log).
///
/// Unselected chips sit on `surface2` with a hairline border; the selected
/// chip fills with `accent`. A null [onSelected] disables the chip.
class HiveFilterChip extends StatelessWidget {
  /// Creates a filter chip.
  const new({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.leading,
    this.count,
    this.semanticLabel,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(count == null || count >= 0, 'count must not be negative.');

  /// Visible text.
  final String label;

  /// Whether the filter is active.
  final bool selected;

  /// Called with the new selection when activated; null disables the chip.
  final ValueChanged<bool>? onSelected;

  /// Optional leading widget sized `space2`, such as a `HiveStatusDot`.
  ///
  /// Its own semantics are excluded; [label] names the chip.
  final Widget? leading;

  /// Optional number of matching items, shown after [label].
  final int? count;

  /// Accessibility label; defaults to [label]. [count] is announced as the
  /// value.
  final String? semanticLabel;

  /// Optional external states controller (hover, focus, pressed).
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final motion = context.hiveMotion;
    final callback = onSelected;
    final lead = leading;
    final total = count;

    final background = selected ? colors.accent : colors.surface2;
    final foreground = selected ? colors.onAccent : colors.onSurface;
    final mutedForeground = selected ? colors.onAccent : colors.onSurfaceMuted;
    final border = selected ? colors.accent : colors.borderSubtle;

    return HiveInteraction(
      semanticLabel: semanticLabel ?? label,
      semanticValue: total?.toString(),
      selected: selected,
      onPressed: callback == null ? null : () => callback(!selected),
      statesController: statesController,
      focusNode: focusNode,
      autofocus: autofocus,
      builder: (context, states) {
        return Opacity(
          opacity: states.contains(WidgetState.disabled)
              ? colors.disabledOpacity
              : 1,
          child: HiveFocusRing(
            focused: states.contains(WidgetState.focused),
            shape: const StadiumBorder(),
            child: AnimatedContainer(
              duration: motion.resolve(context, motion.short),
              curve: motion.standardCurve,
              constraints: BoxConstraints(minHeight: spacing.space4),
              padding: EdgeInsets.symmetric(horizontal: spacing.space2),
              decoration: ShapeDecoration(
                color: hiveStateLayer(
                  base: background,
                  foreground: foreground,
                  states: states,
                  colors: colors,
                ),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: border,
                    width: context.hiveElevation.hairline,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (lead != null) ...<Widget>[
                    SizedBox.square(
                      dimension: spacing.space2,
                      child: Center(child: lead),
                    ),
                    SizedBox(width: spacing.spaceHalf),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.label.copyWith(color: foreground),
                    ),
                  ),
                  if (total != null) ...<Widget>[
                    SizedBox(width: spacing.spaceHalf),
                    Text(
                      '$total',
                      maxLines: 1,
                      style: typography.mono.copyWith(color: mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
