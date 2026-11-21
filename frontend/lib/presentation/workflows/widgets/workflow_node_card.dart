import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_graph_painter.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Interactive node card rendered on the workflow graph canvas.
class WorkflowNodeCard extends StatelessWidget {
  /// Creates a [WorkflowNodeCard].
  const new({
    required this.node,
    required this.isSelected,
    required this.isEntryNode,
    required this.hasError,
    required this.hasWarning,
    required this.onTap,
    required this.onDragDelta,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
    super.key,
  });

  /// Node data to render.
  final WorkflowNode node;

  /// Whether this node is currently selected.
  final bool isSelected;

  /// Whether this node is the workflow's `entryNodeId`.
  final bool isEntryNode;

  /// Whether this node has any error-severity validation issues.
  final bool hasError;

  /// Whether this node has any warning-severity validation issues.
  final bool hasWarning;

  /// Called when the user taps the node to select it.
  final VoidCallback onTap;

  /// Called when the user drags the node card to reposition it.
  final ValueChanged<Offset> onDragDelta;

  /// Called when the user starts dragging from the output port.
  final ValueChanged<DragStartDetails> onPortDragStart;

  /// Called while the user drags from the output port.
  final ValueChanged<DragUpdateDetails> onPortDragUpdate;

  /// Called when the user releases the output port drag.
  final ValueChanged<DragEndDetails> onPortDragEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final motion = context.hiveMotion;
    final elevation = context.hiveElevation;

    final scope = context.dependOnInheritedWidgetOfExactType<NodeVisualScope>();
    final visual = scope != null
        ? scope.registry.resolve(node.type)
        : NodeVisual.fallback;
    final iconColor = visual.accent?.call(colors) ?? colors.onSurface;

    final borderColor = isSelected
        ? colors.accent
        : hasError
        ? colors.danger
        : hasWarning
        ? colors.warning
        : colors.borderSubtle;

    return HiveFadeIn(
      child: SizedBox(
        width: WorkflowCanvasGeometry.nodeWidth,
        height: WorkflowCanvasGeometry.nodeHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: onTap,
                onPanUpdate: (details) => onDragDelta(details.delta),
                child: Semantics(
                  label: node.label,
                  selected: isSelected,
                  button: true,
                  child: AnimatedContainer(
                    duration: motion.resolve(context, motion.short),
                    curve: motion.standardCurve,
                    padding: EdgeInsets.all(spacing.space2),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.surface3 : colors.surface2,
                      borderRadius: context.hiveRadii.card,
                      border: Border.all(
                        color: borderColor,
                        width: isSelected
                            ? elevation.focusRingWidth
                            : elevation.hairline,
                      ),
                      boxShadow: elevation.shadowSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            HiveIcon(
                              visual.icon,
                              size: spacing.space2,
                              color: iconColor,
                            ),
                            SizedBox(width: spacing.space1),
                            Expanded(
                              child: Text(
                                node.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.labelLarge.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            if (hasError)
                              HiveIcon(
                                HiveIcons.alert,
                                size: spacing.space2,
                                color: colors.danger,
                              )
                            else if (hasWarning)
                              HiveIcon(
                                HiveIcons.alert,
                                size: spacing.space2,
                                color: colors.warning,
                              ),
                          ],
                        ),
                        SizedBox(height: spacing.spaceHalf),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                node.type == 'placeholder'
                                    ? l10n.editorNodeTypePlaceholder
                                    : node.type,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.bodySmall.copyWith(
                                  color: colors.onSurfaceMuted,
                                ),
                              ),
                            ),
                            if (isEntryNode)
                              HiveBadge(
                                label: l10n.editorEntryBadge,
                                tone: HiveBadgeTone.accentMuted,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Input port indicator (left)
            Positioned(
              left: -spacing.spaceHalf,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface3,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.borderSubtle,
                    width: elevation.hairline,
                  ),
                ),
                child: SizedBox.square(dimension: spacing.space1),
              ),
            ),
            // Output port drag handle (right)
            Positioned(
              right: -spacing.space1,
              child: Tooltip(
                message: l10n.editorOutputPortTooltip,
                child: Semantics(
                  label: l10n.editorOutputPortTooltip,
                  button: true,
                  child: GestureDetector(
                    key: Key('output_port_${node.id}'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: onPortDragStart,
                    onPanUpdate: onPortDragUpdate,
                    onPanEnd: onPortDragEnd,
                    child: Padding(
                      padding: EdgeInsets.all(spacing.spaceHalf),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isSelected ? colors.accent : colors.surface3,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? colors.onAccent
                                : colors.onSurfaceMuted,
                            width: elevation.hairline,
                          ),
                        ),
                        child: SizedBox.square(dimension: spacing.space2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
