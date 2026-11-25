import 'package:agentic_hive_frontend/domain/runs/fan_out_progress.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/fan_out_children_panel.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_graph_painter.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Read-only interactive workflow graph view for the Live Run Monitor.
///
/// Reuses [WorkflowCanvasGeometry], [WorkflowGridPainter], and
/// [WorkflowEdgesPainter] from the workflow editor, overlaying real-time
/// [HiveNodeStatus] indicators on each node and supporting pan/zoom and
/// node selection.
class RunGraphView extends StatefulWidget {
  /// Creates a [RunGraphView].
  const new({
    required this.workflow,
    required this.nodeStatuses,
    required this.selectedNodeId,
    required this.onSelectNode,
    this.fanOutProgress = const <String, FanOutProgress>{},
    super.key,
  });

  /// Workflow definition snapshot for the run.
  final Workflow workflow;

  /// Live status per node ID.
  final Map<String, HiveNodeStatus> nodeStatuses;

  /// Currently inspected node ID, if any.
  final String? selectedNodeId;

  /// Called when the user taps a node on the canvas.
  final ValueChanged<String> onSelectNode;

  /// Progress summaries keyed by fan-out node ID.
  final Map<String, FanOutProgress> fanOutProgress;

  @override
  State<RunGraphView> createState() => _RunGraphViewState();
}

class _RunGraphViewState extends State<RunGraphView> {
  final TransformationController _transformationController =
      TransformationController();
  late final NodeVisualRegistry _visualRegistry = createNodeVisualRegistry();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomBy(double factor) {
    final current = _transformationController.value.clone();
    final currentScale = current.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(0.4, 2.0);
    final appliedFactor = nextScale / currentScale;
    current.scaleByDouble(appliedFactor, appliedFactor, 1, 1);
    _transformationController.value = current;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final elevation = context.hiveElevation;

    final nodes = widget.workflow.nodes;
    final edges = widget.workflow.edges;

    return NodeVisualScope(
      registry: _visualRegistry,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: context.hiveRadii.panel,
          border: Border.all(
            color: colors.borderSubtle,
            width: elevation.hairline,
          ),
        ),
        child: ClipRRect(
          borderRadius: context.hiveRadii.panel,
          child: Stack(
            children: <Widget>[
              InteractiveViewer(
                transformationController: _transformationController,
                constrained: false,
                boundaryMargin: EdgeInsets.all(spacing.space8 * 4),
                minScale: 0.4,
                maxScale: 2,
                child: SizedBox(
                  width: WorkflowCanvasGeometry.canvasWidth,
                  height: WorkflowCanvasGeometry.canvasHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: CustomPaint(
                          painter: WorkflowGridPainter(
                            dotColor: colors.borderSubtle,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: WorkflowEdgesPainter(
                            nodes: nodes,
                            edges: edges,
                            selectedEdgeId: null,
                            errorEdgeIds: const <String>{},
                            warningEdgeIds: const <String>{},
                            colors: colors,
                            typography: typography,
                            flowPhase: 0,
                          ),
                        ),
                      ),
                      for (final node in nodes)
                        Positioned(
                          key: Key('run_graph_node_${node.id}'),
                          left: node.position.x,
                          top: node.position.y,
                          child: _RunNodeCard(
                            node: node,
                            status:
                                widget.nodeStatuses[node.id] ??
                                HiveNodeStatus.idle,
                            isSelected: widget.selectedNodeId == node.id,
                            progress: widget.fanOutProgress[node.id],
                            onTap: () => widget.onSelectNode(node.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: spacing.space2,
                top: spacing.space2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: context.hiveRadii.pill,
                    border: Border.all(
                      color: colors.borderSubtle,
                      width: elevation.hairline,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.space2,
                      vertical: spacing.space1,
                    ),
                    child: Text(
                      l10n.runDetailGraphTitle,
                      style: typography.label.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: spacing.space2,
                bottom: spacing.space2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: context.hiveRadii.pill,
                    border: Border.all(
                      color: colors.borderSubtle,
                      width: elevation.hairline,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.spaceHalf),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        HiveIconButton(
                          icon: HiveIcons.add,
                          size: HiveButtonSize.small,
                          semanticLabel: l10n.editorZoomInTooltip,
                          onPressed: () => _zoomBy(1.2),
                        ),
                        HiveIconButton(
                          icon: HiveIcons.close,
                          size: HiveButtonSize.small,
                          semanticLabel: l10n.editorZoomOutTooltip,
                          onPressed: () => _zoomBy(0.8),
                        ),
                        HiveIconButton(
                          icon: HiveIcons.refresh,
                          size: HiveButtonSize.small,
                          semanticLabel: l10n.editorZoomResetTooltip,
                          onPressed: _resetZoom,
                        ),
                      ],
                    ),
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

class _RunNodeCard extends StatelessWidget {
  const new({
    required this.node,
    required this.status,
    required this.isSelected,
    required this.onTap,
    this.progress,
  });

  final WorkflowNode node;
  final HiveNodeStatus status;
  final bool isSelected;
  final FanOutProgress? progress;
  final VoidCallback onTap;

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
        : switch (status) {
            HiveNodeStatus.running => colors.accent,
            HiveNodeStatus.succeeded => colors.success,
            HiveNodeStatus.failed ||
            HiveNodeStatus.cancellationUncertain => colors.danger,
            HiveNodeStatus.paused ||
            HiveNodeStatus.cancelling ||
            HiveNodeStatus.interrupted => colors.warning,
            HiveNodeStatus.idle ||
            HiveNodeStatus.cancelled => colors.borderSubtle,
          };

    final statusLabel = RunL10n.localizeNodeStatus(l10n, status);
    final currentProgress = progress;
    final hasProgressLine =
        currentProgress != null &&
        (currentProgress.emptyList || !currentProgress.isEmpty);
    final subtitleText = currentProgress == null
        ? resolveNodeVisualLabel(l10n, visual.labelKey)
        : (currentProgress.emptyList
              ? l10n.runDetailFanOutNoItems
              : (!currentProgress.isEmpty
                    ? fanOutProgressText(l10n, currentProgress)
                    : resolveNodeVisualLabel(l10n, visual.labelKey)));
    final needsHuman = currentProgress?.needsHuman ?? 0;
    final needsYouText = needsHuman > 0
        ? l10n.runDetailFanOutNeedsYou(needsHuman)
        : null;
    final semanticsLabel = needsYouText == null
        ? '${node.label} ($statusLabel)'
        : '${node.label} ($statusLabel), $needsYouText';

    return SizedBox(
      width: WorkflowCanvasGeometry.nodeWidth,
      height: WorkflowCanvasGeometry.nodeHeight,
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          label: semanticsLabel,
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
                    SizedBox(width: spacing.space1),
                    HiveStatusDot(
                      key: Key('run_graph_node_status_${node.id}'),
                      status: status,
                      semanticLabel: statusLabel,
                      size: spacing.space2,
                    ),
                  ],
                ),
                SizedBox(height: spacing.spaceHalf),
                Text(
                  subtitleText,
                  key: hasProgressLine
                      ? Key('run_graph_node_progress_${node.id}')
                      : null,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySmall.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
