import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// One destination in a `HiveSideRail`.
///
/// Collapsed, it is a circle with the icon; the active item is a filled
/// `accent` circle. Expanded, it becomes a pill with the label next to the
/// circle.
///
/// A positive [badgeCount] adds a `warning` count pill: on the circle's
/// top-right edge while collapsed, at the end of the pill while expanded.
/// Counts above [maxBadgeCount] show as `99+`. The pill is not announced on
/// its own; pass a [semanticLabel] such as `Pauses, 3 pending` so screen
/// readers hear the count.
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
    this.badgeCount,
    this.semanticLabel,
    super.key,
  });

  /// Largest count the badge shows in full; larger counts show as `99+`.
  static const int maxBadgeCount = 99;

  /// The text a badge shows for [count]: the count up to [maxBadgeCount],
  /// then `99+`.
  static String badgeText(int count) =>
      count > maxBadgeCount ? '$maxBadgeCount+' : '$count';

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

  /// Pending count shown in a `warning` pill; null or not positive hides it.
  final int? badgeCount;

  /// Accessibility label; defaults to [label]. Include the badge count here
  /// (for example `Pauses, 3 pending`), since the pill itself is silent.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final diameter = spacing.space6;
    final count = badgeCount;
    final badge = count != null && count > 0
        ? _RailBadge(text: badgeText(count))
        : null;

    return HiveInteraction(
      semanticLabel: semanticLabel ?? label,
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
        // Collapsed, the pill sits inside the circle's top-right corner: the
        // rail's scroll view clips anything past the item's bounds.
        final collapsedCircle = badge == null || expanded
            ? circle
            : Stack(
                children: <Widget>[
                  circle,
                  Positioned(top: 0, right: 0, child: badge),
                ],
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
                                right: badge == null
                                    ? spacing.space2
                                    : spacing.space1,
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
                          if (badge != null)
                            Padding(
                              padding: EdgeInsets.only(right: spacing.space2),
                              child: badge,
                            ),
                        ],
                      )
                    : collapsedCircle,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The count pill of a [HiveRailItem]: `onWarning` text on `warning`, ringed
/// in `background` so it stays distinct over the active `accent` circle.
class _RailBadge extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final ring = context.hiveElevation.hairline;
    return ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(
          minWidth: spacing.space2 + ring * 2,
          minHeight: spacing.space2 + ring * 2,
        ),
        padding: EdgeInsets.symmetric(horizontal: spacing.spaceHalf),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: colors.warning,
          shape: StadiumBorder(
            side: BorderSide(color: colors.background, width: ring),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: context.hiveTypography.label.copyWith(color: colors.onWarning),
        ),
      ),
    );
  }
}
