import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// A single row in a hierarchical tree inside the side rail.
///
/// Supports optional indentation, an expand/collapse chevron, a leading status
/// or icon widget, a primary [label] with an optional muted [subtitle], a
/// [trailing] badge or indicator, and [selected] / [highlighted] states.
class HiveTreeItem extends StatefulWidget {
  /// Creates a tree item.
  const new({
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.indentLevel = 0,
    this.leading,
    this.trailing,
    this.expanded,
    this.onToggleExpand,
    this.selected = false,
    this.highlighted = false,
    this.semanticLabel,
    this.expandSemanticLabel,
    this.statesController,
    this.focusNode,
    super.key,
  }) : assert(indentLevel >= 0, 'indentLevel must be non-negative');

  /// Primary text of the tree item.
  final String label;

  /// Optional secondary muted line under [label], such as a branch name or
  /// elapsed time.
  final String? subtitle;

  /// Zero-based nesting depth; each level indents by `space2`.
  final int indentLevel;

  /// Optional leading widget (for example a `HiveStatusDot` or `HiveIcon`).
  final Widget? leading;

  /// Optional trailing widget (for example a `HiveBadge`).
  final Widget? trailing;

  /// Expansion state for branch items, or null for leaf items.
  final bool? expanded;

  /// Called when the expand/collapse chevron is activated.
  final VoidCallback? onToggleExpand;

  /// Called when the item is activated; null disables the item when
  /// [onToggleExpand] is also null.
  final VoidCallback? onPressed;

  /// Whether this item is currently selected.
  final bool selected;

  /// Whether this item is highlighted (for example a run with a pending pause).
  final bool highlighted;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;

  /// Accessibility label for the expand/collapse chevron when [onToggleExpand]
  /// is provided.
  final String? expandSemanticLabel;

  /// Optional external states controller (hover, focus, pressed).
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  @override
  State<HiveTreeItem> createState() => _HiveTreeItemState();
}

class _HiveTreeItemState extends State<HiveTreeItem> {
  WidgetStatesController? _ownController;

  WidgetStatesController get _controller =>
      widget.statesController ?? (_ownController ??= WidgetStatesController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStatesChanged);
  }

  @override
  void didUpdateWidget(HiveTreeItem oldWidget) {
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
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final motion = context.hiveMotion;
    final duration = motion.resolve(context, motion.short);
    final subtitleText = widget.subtitle;
    final leadingWidget = widget.leading;
    final trailingWidget = widget.trailing;
    final isExpanded = widget.expanded;
    final states = _controller.value;
    final disabled = widget.onPressed == null && widget.onToggleExpand == null;

    var baseColor = widget.selected
        ? colors.surface3
        : colors.background.withValues(alpha: 0);
    if (widget.highlighted) {
      baseColor = Color.alphaBlend(
        colors.warning.withValues(alpha: colors.hoverOpacity),
        baseColor,
      );
    }
    final backgroundColor = hiveStateLayer(
      base: baseColor,
      foreground: colors.onSurface,
      states: states,
      colors: colors,
    );
    final borderSide = widget.highlighted
        ? BorderSide(
            color: colors.warning,
            width: context.hiveElevation.hairline,
          )
        : BorderSide.none;

    Widget? chevron;
    if (isExpanded != null) {
      final chevronGlyph = Padding(
        padding: EdgeInsets.all(spacing.spaceHalf),
        child: AnimatedRotation(
          turns: isExpanded ? 0 : -0.25,
          duration: duration,
          curve: motion.standardCurve,
          child: HiveIcon(
            HiveIcons.chevronDown,
            size: spacing.space2,
            color: colors.onSurfaceMuted,
          ),
        ),
      );
      final onToggle = widget.onToggleExpand;
      chevron = onToggle != null
          ? HiveInteraction(
              semanticLabel:
                  widget.expandSemanticLabel ??
                  (isExpanded
                      ? 'Collapse ${widget.label}'
                      : 'Expand ${widget.label}'),
              expanded: isExpanded,
              onPressed: onToggle,
              builder: (context, chevronStates) => HiveFocusRing(
                focused: chevronStates.contains(WidgetState.focused),
                shape: const CircleBorder(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hiveStateLayer(
                      base: colors.background.withValues(alpha: 0),
                      foreground: colors.onSurface,
                      states: chevronStates,
                      colors: colors,
                    ),
                  ),
                  child: chevronGlyph,
                ),
              ),
            )
          : chevronGlyph;
    }

    return Opacity(
      opacity: disabled ? colors.disabledOpacity : 1,
      child: HiveFocusRing(
        focused: states.contains(WidgetState.focused),
        shape: const StadiumBorder(),
        child: AnimatedContainer(
          duration: duration,
          curve: motion.standardCurve,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.space1,
            vertical: spacing.spaceHalf,
          ),
          decoration: ShapeDecoration(
            color: backgroundColor,
            shape: StadiumBorder(side: borderSide),
          ),
          child: Row(
            children: <Widget>[
              if (widget.indentLevel > 0)
                SizedBox(width: widget.indentLevel * spacing.space2),
              if (chevron != null) ...<Widget>[
                chevron,
                SizedBox(width: spacing.spaceHalf),
              ],
              Expanded(
                child: HiveInteraction(
                  semanticLabel: widget.semanticLabel ?? widget.label,
                  onPressed: widget.onPressed,
                  selected: widget.selected,
                  expanded: widget.onToggleExpand == null ? isExpanded : null,
                  statesController: _controller,
                  focusNode: widget.focusNode,
                  builder: (context, _) => Row(
                    children: <Widget>[
                      if (leadingWidget != null) ...<Widget>[
                        leadingWidget,
                        SizedBox(width: spacing.space1),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: typography.labelLarge.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            if (subtitleText != null)
                              Text(
                                subtitleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: typography.bodySmall.copyWith(
                                  color: colors.onSurfaceMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (trailingWidget != null) ...<Widget>[
                        SizedBox(width: spacing.space1),
                        trailingWidget,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
