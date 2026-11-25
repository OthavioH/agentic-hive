import 'dart:async';

import 'package:design_system/src/components/hive_hex_mark.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/components/hive_rail_item.dart';
import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A destination of a [HiveSideRail].
@immutable
class HiveRailDestination {
  /// Creates a destination.
  const new({
    required this.icon,
    required this.label,
    this.badgeCount,
    this.semanticLabel,
  });

  /// Destination icon.
  final HiveIconData icon;

  /// Localized destination name.
  final String label;

  /// Pending count shown on the item; see [HiveRailItem.badgeCount].
  final int? badgeCount;

  /// Localized accessibility label including the count (for example
  /// `Pauses, 3 pending`); defaults to [label].
  final String? semanticLabel;
}

/// Programmatic controller for opening or closing a [HiveRailSection] panel.
class HiveRailSectionController extends ChangeNotifier {
  /// Creates a [HiveRailSectionController].
  new();

  bool? _pendingOpen;

  /// Requests the attached panel to open.
  void open() {
    _pendingOpen = true;
    notifyListeners();
  }

  /// Requests the attached panel to close (when unpinned).
  void close() {
    _pendingOpen = false;
    notifyListeners();
  }

  /// Requests the attached panel to toggle (when unpinned).
  void toggle() {
    _pendingOpen = null;
    notifyListeners();
  }

  bool? _consumePending() {
    final value = _pendingOpen;
    _pendingOpen = null;
    return value;
  }
}

/// Optional section hosted below the destinations of a [HiveSideRail],
/// opening an attached flyout panel on the rail's right edge.
@immutable
class HiveRailSection {
  /// Creates a [HiveRailSection].
  const new({
    required this.icon,
    required this.label,
    required this.title,
    required this.child,
    this.trailing,
    this.badgeCount,
    this.semanticLabel,
    this.pinned = false,
    this.onPinnedChanged,
    this.pinLabel = 'Pin panel',
    this.unpinLabel = 'Unpin panel',
    this.controller,
  });

  /// Section entry icon.
  final HiveIconData icon;

  /// Localized section entry label (shown when the rail is expanded).
  final String label;

  /// Panel header title.
  final String title;

  /// Panel body; fills the remaining height below the header.
  final Widget child;

  /// Optional trailing actions placed in the panel header before the pin
  /// toggle.
  final Widget? trailing;

  /// Pending/active count shown on the entry; see [HiveRailItem.badgeCount].
  final int? badgeCount;

  /// Accessibility label for the section entry; defaults to [label].
  final String? semanticLabel;

  /// Whether the panel is pinned beside the rail.
  final bool pinned;

  /// Called when the user toggles the panel's pin button.
  final ValueChanged<bool>? onPinnedChanged;

  /// Accessibility label for the pin button when unpinned.
  final String pinLabel;

  /// Accessibility label for the pin button when pinned.
  final String unpinLabel;

  /// Optional controller to open or close the unpinned panel programmatically.
  final HiveRailSectionController? controller;
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
    this.section,
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

  /// Optional section hosted below the destinations.
  final HiveRailSection? section;

  @override
  State<HiveSideRail> createState() => _HiveSideRailState();
}

class _HiveSideRailState extends State<HiveSideRail> {
  late bool _expanded = widget.initiallyExpanded;
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  final Object _tapRegionGroupId = Object();
  final FocusNode _sectionEntryFocusNode = FocusNode();
  final FocusScopeNode _panelFocusScopeNode = FocusScopeNode();

  Timer? _hoverOpenTimer;
  Timer? _hoverCloseTimer;
  bool _pointerInEntry = false;
  bool _pointerInPanel = false;
  bool _isPanelOpen = false;
  double? _railHeight;

  bool get _isExpanded => widget.expanded ?? _expanded;
  bool get _isCurrentRoute => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  void initState() {
    super.initState();
    widget.section?.controller?.addListener(_onSectionControllerChanged);
  }

  @override
  void didUpdateWidget(covariant HiveSideRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section?.controller != widget.section?.controller) {
      oldWidget.section?.controller?.removeListener(
        _onSectionControllerChanged,
      );
      widget.section?.controller?.addListener(_onSectionControllerChanged);
    }
    final section = widget.section;
    if (section == null || section.pinned) {
      _cancelTimers();
      _isPanelOpen = false;
      if (_overlayController.isShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_overlayController.isShowing) return;
          final current = widget.section;
          if (current == null || current.pinned) {
            _overlayController.hide();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    widget.section?.controller?.removeListener(_onSectionControllerChanged);
    _cancelTimers();
    _sectionEntryFocusNode.dispose();
    _panelFocusScopeNode.dispose();
    super.dispose();
  }

  void _onSectionControllerChanged() {
    final section = widget.section;
    final controller = section?.controller;
    if (section == null || controller == null || section.pinned) return;
    final pending = controller._consumePending();
    if (pending == null) {
      _togglePanel();
    } else if (pending) {
      _openPanel();
    } else {
      _closePanel();
    }
  }

  void _cancelTimers() {
    _hoverOpenTimer?.cancel();
    _hoverOpenTimer = null;
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = null;
  }

  void _toggle() {
    final next = !_isExpanded;
    if (widget.expanded == null) setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  void _openPanel({bool focusPanel = false}) {
    final section = widget.section;
    if (section == null || section.pinned) return;
    _cancelTimers();
    if (!_isPanelOpen) {
      setState(() => _isPanelOpen = true);
      if (!_overlayController.isShowing) {
        _overlayController.show();
      }
    }
    if (focusPanel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _panelFocusScopeNode
          ..requestFocus()
          ..nextFocus();
      });
    }
  }

  void _closePanel({bool returnFocus = false}) {
    _cancelTimers();
    if (_isPanelOpen || _overlayController.isShowing) {
      setState(() => _isPanelOpen = false);
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
    }
    if (returnFocus) {
      _sectionEntryFocusNode.requestFocus();
    }
  }

  void _togglePanel() {
    final section = widget.section;
    if (section == null || section.pinned) return;
    if (_isPanelOpen) {
      _closePanel();
    } else {
      _openPanel();
    }
  }

  void _onEntryHoverEnter() {
    _pointerInEntry = true;
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = null;
    final section = widget.section;
    if (section == null || section.pinned || _isPanelOpen) return;
    final motion = context.hiveMotion;
    final delay = motion.resolve(context, motion.short);
    if (delay == Duration.zero) {
      _openPanel();
      return;
    }
    _hoverOpenTimer?.cancel();
    _hoverOpenTimer = Timer(delay, () {
      if (mounted && _pointerInEntry && !(widget.section?.pinned ?? false)) {
        _openPanel();
      }
    });
  }

  void _onEntryHoverExit() {
    _pointerInEntry = false;
    _hoverOpenTimer?.cancel();
    _hoverOpenTimer = null;
    _scheduleHoverClose();
  }

  void _onPanelHoverEnter() {
    _pointerInPanel = true;
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = null;
  }

  void _onPanelHoverExit() {
    _pointerInPanel = false;
    _scheduleHoverClose();
  }

  void _scheduleHoverClose() {
    final section = widget.section;
    if (section == null || section.pinned || !_isPanelOpen) return;
    if (_pointerInEntry || _pointerInPanel || !_isCurrentRoute) return;
    final motion = context.hiveMotion;
    final delay = motion.resolve(context, motion.medium);
    _hoverCloseTimer?.cancel();
    if (delay == Duration.zero) {
      _closePanel();
      return;
    }
    _hoverCloseTimer = Timer(delay, () {
      if (!mounted) return;
      if (!_pointerInEntry &&
          !_pointerInPanel &&
          _isCurrentRoute &&
          !(widget.section?.pinned ?? false)) {
        _closePanel();
      }
    });
  }

  KeyEventResult _handleEntryKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.arrowRight) {
      _openPanel(focusPanel: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape &&
        _isPanelOpen &&
        !(widget.section?.pinned ?? false)) {
      _closePanel(returnFocus: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handlePanelKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        !(widget.section?.pinned ?? false)) {
      _closePanel(returnFocus: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildPanel(BuildContext context, HiveRailSection section) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final panelWidth = spacing.space8 * 5 + spacing.space2;

    return FocusScope(
      node: _panelFocusScopeNode,
      onKeyEvent: _handlePanelKeyEvent,
      child: MouseRegion(
        onEnter: (_) => _onPanelHoverEnter(),
        onExit: (_) => _onPanelHoverExit(),
        child: TapRegion(
          groupId: _tapRegionGroupId,
          child: Container(
            width: panelWidth,
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: context.hiveRadii.panel,
              border: Border.all(
                color: colors.borderSubtle,
                width: context.hiveElevation.hairline,
              ),
              boxShadow: context.hiveElevation.shadowMedium,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.space2,
                    spacing.space2,
                    spacing.space1,
                    spacing.space1,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          section.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.title.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (section.trailing != null) section.trailing!,
                      HiveIconButton(
                        icon: HiveIcons.pin,
                        semanticLabel: section.pinned
                            ? section.unpinLabel
                            : section.pinLabel,
                        onPressed: section.onPinnedChanged == null
                            ? null
                            : () => section.onPinnedChanged!(!section.pinned),
                      ),
                    ],
                  ),
                ),
                Expanded(child: section.child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final expanded = _isExpanded;
    final section = widget.section;
    // Items are `space6` circles; add the horizontal padding and the hairline
    // border on both sides so they keep their full size.
    final collapsedWidth =
        spacing.space6 +
        spacing.space1 * 2 +
        context.hiveElevation.hairline * 2;
    final expandedWidth = spacing.space8 * 4;

    final railBody = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight) {
          _railHeight = constraints.maxHeight;
        }
        return CompositedTransformTarget(
          link: _layerLink,
          child: Semantics(
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
                      colors.accentMuted.withValues(
                        alpha: colors.pressedOpacity,
                      ),
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
                    alignment: expanded
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.spaceHalf,
                      ),
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
                          for (
                            var i = 0;
                            i < widget.destinations.length;
                            i++
                          ) ...[
                            if (i > 0) SizedBox(height: spacing.space1),
                            HiveRailItem(
                              icon: widget.destinations[i].icon,
                              label: widget.destinations[i].label,
                              selected: i == widget.selectedIndex,
                              expanded: expanded,
                              badgeCount: widget.destinations[i].badgeCount,
                              semanticLabel:
                                  widget.destinations[i].semanticLabel,
                              onPressed: () => widget.onSelected(i),
                            ),
                          ],
                          if (section != null) ...[
                            SizedBox(height: spacing.space1),
                            Container(
                              height: context.hiveElevation.hairline,
                              color: colors.borderSubtle,
                            ),
                            SizedBox(height: spacing.space1),
                            _buildSectionEntry(
                              context,
                              section: section,
                              expanded: expanded,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.space2),
                  Align(
                    alignment: expanded
                        ? Alignment.centerRight
                        : Alignment.center,
                    child: HiveIconButton(
                      icon: expanded
                          ? HiveIcons.collapseRail
                          : HiveIcons.expandRail,
                      semanticLabel: expanded
                          ? widget.collapseLabel
                          : widget.expandLabel,
                      onPressed: _toggle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (section == null) return railBody;

    if (section.pinned) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          railBody,
          SizedBox(width: spacing.space1),
          _buildPanel(context, section),
        ],
      );
    }

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (overlayContext) {
        final panel = _buildPanel(overlayContext, section);
        return Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topRight,
            offset: Offset(spacing.space1, 0),
            child: SizedBox(height: _railHeight, child: panel),
          ),
        );
      },
      child: railBody,
    );
  }

  Widget _buildSectionEntry(
    BuildContext context, {
    required HiveRailSection section,
    required bool expanded,
  }) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final diameter = spacing.space6;
    final active = _isPanelOpen || section.pinned;
    final count = section.badgeCount;
    final hasBadge = count != null && count > 0;

    return Focus(
      onKeyEvent: _handleEntryKeyEvent,
      skipTraversal: true,
      child: MouseRegion(
        onEnter: (_) => _onEntryHoverEnter(),
        onExit: (_) => _onEntryHoverExit(),
        child: TapRegion(
          groupId: _tapRegionGroupId,
          onTapOutside: (_) {
            if (_isCurrentRoute && !section.pinned && _isPanelOpen) {
              _closePanel();
            }
          },
          child: HiveInteraction(
            semanticLabel: section.semanticLabel ?? section.label,
            onPressed: section.pinned ? null : _togglePanel,
            selected: active,
            focusNode: _sectionEntryFocusNode,
            builder: (context, states) {
              final circleColor = active
                  ? hiveStateLayer(
                      base: colors.accent,
                      foreground: colors.onAccent,
                      states: states,
                      colors: colors,
                    )
                  : colors.background.withValues(alpha: 0);
              final pillColor = hiveStateLayer(
                base: active && expanded
                    ? colors.surface3
                    : colors.background.withValues(alpha: 0),
                foreground: colors.onSurface,
                states: active && !expanded ? const <WidgetState>{} : states,
                colors: colors,
              );
              final iconColor = active
                  ? colors.onAccent
                  : colors.onSurfaceMuted;
              final circle = AnimatedContainer(
                duration: motion.resolve(context, motion.short),
                curve: motion.standardCurve,
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: HiveIcon(
                  section.icon,
                  size: spacing.space3,
                  color: iconColor,
                ),
              );

              final collapsedCircle = expanded
                  ? circle
                  : Stack(
                      children: <Widget>[
                        circle,
                        if (hasBadge)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: _SectionBadge(
                              text: HiveRailItem.badgeText(count),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: ExcludeSemantics(
                            child: HiveIcon(
                              HiveIcons.chevronRight,
                              size: spacing.space2,
                              color: active
                                  ? colors.onAccent
                                  : colors.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ],
                    );

              return HiveFocusRing(
                focused: states.contains(WidgetState.focused),
                shape: expanded ? const StadiumBorder() : const CircleBorder(),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (!expanded ||
                            constraints.maxWidth < diameter + spacing.space4) {
                          return collapsedCircle;
                        }
                        return Row(
                          children: <Widget>[
                            circle,
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: spacing.space1,
                                  right: spacing.space1,
                                ),
                                child: Text(
                                  section.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: context.hiveTypography.labelLarge
                                      .copyWith(
                                        color: active
                                            ? colors.onSurface
                                            : colors.onSurfaceMuted,
                                      ),
                                ),
                              ),
                            ),
                            if (hasBadge)
                              Padding(
                                padding: EdgeInsets.only(right: spacing.space1),
                                child: _SectionBadge(
                                  text: HiveRailItem.badgeText(count),
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.only(right: spacing.space1),
                              child: ExcludeSemantics(
                                child: HiveIcon(
                                  HiveIcons.chevronRight,
                                  size: spacing.space2,
                                  color: colors.onSurfaceMuted,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionBadge extends StatelessWidget {
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
