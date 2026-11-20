import 'package:design_system/src/components/hive_hex_mark.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/components/hive_rail_item.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A destination of a [HiveSideRail].
@immutable
class HiveRailDestination {
  /// Creates a destination.
  const new({required this.icon, required this.label});

  /// Destination icon.
  final HiveIconData icon;

  /// Localized destination name.
  final String label;
}

/// The app's floating pill-shaped navigation rail.
///
/// Collapsed by default (icons only) and expandable to show labels. The Hive
/// hexagon mark sits on top, the active destination is a filled `accent`
/// circle, and the background is the app's only gradient: a subtle green to
/// black vertical fade.
///
/// The expanded state is internal unless [expanded] is given; then the
/// parent owns it and listens through [onExpandedChanged].
class HiveSideRail extends StatefulWidget {
  /// Creates a rail.
  const new({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.markLabel,
    required this.expandLabel,
    required this.collapseLabel,
    this.expanded,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
    super.key,
  });

  /// Destinations from top to bottom.
  final List<HiveRailDestination> destinations;

  /// Index of the active destination, or null when none is active.
  final int? selectedIndex;

  /// Called with the index of an activated destination.
  final ValueChanged<int> onSelected;

  /// Accessibility label of the hexagon mark (the product name).
  final String markLabel;

  /// Accessibility label of the toggle while collapsed.
  final String expandLabel;

  /// Accessibility label of the toggle while expanded.
  final String collapseLabel;

  /// Controlled expanded state; null lets the rail own it.
  final bool? expanded;

  /// Initial expanded state when the rail owns it.
  final bool initiallyExpanded;

  /// Called when the toggle asks to expand or collapse.
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<HiveSideRail> createState() => _HiveSideRailState();
}

class _HiveSideRailState extends State<HiveSideRail> {
  late bool _expanded = widget.initiallyExpanded;

  bool get _isExpanded => widget.expanded ?? _expanded;

  void _toggle() {
    final next = !_isExpanded;
    if (widget.expanded == null) setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final expanded = _isExpanded;
    // Items are `space6` circles; add the horizontal padding and the hairline
    // border on both sides so they keep their full size.
    final collapsedWidth =
        spacing.space6 +
        spacing.space1 * 2 +
        context.hiveElevation.hairline * 2;
    final expandedWidth = spacing.space8 * 4;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: AnimatedContainer(
        duration: motion.resolve(context, motion.medium),
        curve: motion.emphasizedCurve,
        width: expanded ? expandedWidth : collapsedWidth,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.space1,
          vertical: spacing.space2,
        ),
        decoration: BoxDecoration(
          borderRadius: context.hiveRadii.panel,
          border: Border.all(
            color: colors.borderSubtle,
            width: context.hiveElevation.hairline,
          ),
          boxShadow: context.hiveElevation.shadowMedium,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.alphaBlend(
                colors.accentMuted.withValues(alpha: colors.pressedOpacity),
                colors.surface1,
              ),
              colors.background,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: expanded
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: <Widget>[
            Align(
              alignment: expanded ? Alignment.centerLeft : Alignment.center,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.spaceHalf),
                child: HiveHexMark(semanticLabel: widget.markLabel),
              ),
            ),
            SizedBox(height: spacing.space3),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: expanded
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.center,
                  children: <Widget>[
                    for (var i = 0; i < widget.destinations.length; i++) ...[
                      if (i > 0) SizedBox(height: spacing.space1),
                      HiveRailItem(
                        icon: widget.destinations[i].icon,
                        label: widget.destinations[i].label,
                        selected: i == widget.selectedIndex,
                        expanded: expanded,
                        onPressed: () => widget.onSelected(i),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.space2),
            Align(
              alignment: expanded ? Alignment.centerRight : Alignment.center,
              child: HiveIconButton(
                icon: expanded ? HiveIcons.collapseRail : HiveIcons.expandRail,
                semanticLabel: expanded
                    ? widget.collapseLabel
                    : widget.expandLabel,
                onPressed: _toggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
