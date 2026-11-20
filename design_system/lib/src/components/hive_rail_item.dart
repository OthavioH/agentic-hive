import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// One destination in a `HiveSideRail`.
///
/// Collapsed, it is a circle with the icon; the active item is a filled
/// `accent` circle. Expanded, it becomes a pill with the label next to the
/// circle.
class HiveRailItem extends StatelessWidget {
  /// Creates a rail item.
  const new({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.expanded = false,
    this.statesController,
    this.focusNode,
    super.key,
  });

  /// Destination icon.
  final HiveIconData icon;

  /// Destination name; visible when [expanded], always the semantics label.
  final String label;

  /// Called when activated.
  final VoidCallback? onPressed;

  /// Whether this is the active destination.
  final bool selected;

  /// Whether the rail shows labels.
  final bool expanded;

  /// Optional external states controller (hover, focus, pressed).
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final diameter = spacing.space6;

    return HiveInteraction(
      semanticLabel: label,
      onPressed: onPressed,
      selected: selected,
      statesController: statesController,
      focusNode: focusNode,
      builder: (context, states) {
        final circleColor = selected
            ? hiveStateLayer(
                base: colors.accent,
                foreground: colors.onAccent,
                states: states,
                colors: colors,
              )
            : colors.background.withValues(alpha: 0);
        final pillColor = hiveStateLayer(
          base: selected && expanded
              ? colors.surface3
              : colors.background.withValues(alpha: 0),
          foreground: colors.onSurface,
          states: selected && !expanded ? const <WidgetState>{} : states,
          colors: colors,
        );
        final iconColor = selected ? colors.onAccent : colors.onSurfaceMuted;
        final circle = AnimatedContainer(
          duration: motion.resolve(context, motion.short),
          curve: motion.standardCurve,
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          child: HiveIcon(icon, size: spacing.space3, color: iconColor),
        );

        return Opacity(
          opacity: states.contains(WidgetState.disabled)
              ? colors.disabledOpacity
              : 1,
          child: HiveFocusRing(
            focused: states.contains(WidgetState.focused),
            shape: expanded ? const StadiumBorder() : const CircleBorder(),
            // Width is not animated: the rail animates its own width, and an
            // expanded item fills it (it needs a bounded width).
            child: SizedBox(
              width: expanded ? null : diameter,
              child: AnimatedContainer(
                duration: motion.resolve(context, motion.short),
                curve: motion.standardCurve,
                height: diameter,
                decoration: ShapeDecoration(
                  color: pillColor,
                  shape: const StadiumBorder(),
                ),
                child: expanded
                    ? Row(
                        children: <Widget>[
                          circle,
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: spacing.space1,
                                right: spacing.space2,
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: context.hiveTypography.labelLarge
                                    .copyWith(
                                      color: selected
                                          ? colors.onSurface
                                          : colors.onSurfaceMuted,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
