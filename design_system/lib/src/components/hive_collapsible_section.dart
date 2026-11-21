import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A `radiusCard` container with a header that expands and collapses its
/// body, for secondary content such as "Capabilities & tools".
///
/// The header has hover, pressed and keyboard focus states, activates with
/// Enter or Space and announces its expanded state. The body keeps its state
/// while collapsed but leaves focus traversal and semantics. Uncontrolled by
/// default ([initiallyExpanded]); pass [expanded] to control it.
class HiveCollapsibleSection extends StatefulWidget {
  /// Creates a collapsible section.
  const new({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.initiallyExpanded = false,
    this.expanded,
    this.onExpansionChanged,
    this.statesController,
    this.focusNode,
    super.key,
  });

  /// Header title; also the header's semantics label.
  final String title;

  /// The collapsible body. Padding is `space2`.
  final Widget child;

  /// Optional muted line under the title, for example a summary.
  final String? subtitle;

  /// Optional widget before the chevron, for example a count badge.
  final Widget? trailing;

  /// Initial state when uncontrolled.
  final bool initiallyExpanded;

  /// Controlled state; null leaves the section uncontrolled.
  final bool? expanded;

  /// Called with the new state when the header is activated.
  final ValueChanged<bool>? onExpansionChanged;

  /// Optional external states of the header for static previews.
  final WidgetStatesController? statesController;

  /// Optional focus node of the header.
  final FocusNode? focusNode;

  @override
  State<HiveCollapsibleSection> createState() => _HiveCollapsibleSectionState();
}

class _HiveCollapsibleSectionState extends State<HiveCollapsibleSection> {
  late bool _expandedState = widget.expanded ?? widget.initiallyExpanded;
  late bool _bodyVisible = _expanded;

  bool get _expanded => widget.expanded ?? _expandedState;

  @override
  void didUpdateWidget(HiveCollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expanded) _bodyVisible = true;
  }

  void _toggle() {
    final next = !_expanded;
    setState(() {
      _expandedState = next;
      if (next) _bodyVisible = true;
    });
    widget.onExpansionChanged?.call(next);
  }

  void _onAnimationEnd() {
    if (!_expanded && _bodyVisible) setState(() => _bodyVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final motion = context.hiveMotion;
    final duration = motion.resolve(context, motion.medium);
    final expanded = _expanded;
    final subtitle = widget.subtitle;
    final trailing = widget.trailing;
    final radius = context.hiveRadii.card;
    if (!expanded && _bodyVisible && duration == Duration.zero) {
      _bodyVisible = false;
    }

    final header = HiveInteraction(
      semanticLabel: widget.title,
      expanded: expanded,
      onPressed: _toggle,
      statesController: widget.statesController,
      focusNode: widget.focusNode,
      builder: (context, states) => HiveFocusRing(
        focused: states.contains(WidgetState.focused),
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: AnimatedContainer(
          duration: motion.resolve(context, motion.short),
          curve: motion.standardCurve,
          padding: EdgeInsets.all(spacing.space2),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: hiveStateLayer(
              base: colors.surface1.withValues(alpha: 0),
              foreground: colors.onSurface,
              states: states,
              colors: colors,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: typography.labelLarge.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: typography.bodySmall.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                SizedBox(width: spacing.space1),
                trailing,
              ],
              SizedBox(width: spacing.space1),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: duration,
                curve: motion.standardCurve,
                child: HiveIcon(
                  HiveIcons.chevronDown,
                  size: spacing.space2,
                  color: colors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colors.borderSubtle,
          width: context.hiveElevation.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          header,
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: expanded ? 1 : 0,
              duration: duration,
              curve: motion.standardCurve,
              onEnd: _onAnimationEnd,
              child: Visibility(
                visible: _bodyVisible,
                maintainState: true,
                child: ExcludeFocus(
                  excluding: !expanded,
                  child: ExcludeSemantics(
                    excluding: !expanded,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        spacing.space2,
                        0,
                        spacing.space2,
                        spacing.space2,
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
