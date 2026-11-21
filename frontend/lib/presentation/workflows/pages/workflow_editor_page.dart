import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/utils/workflow_l10n.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_graph_painter.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_inspector_panel.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_node_card.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

final class _DeleteSelectedIntent extends Intent {
  const new();
}

final class _SaveWorkflowIntent extends Intent {
  const new();
}

final class _DeleteSelectedAction extends Action<_DeleteSelectedIntent> {
  new(this._onDelete);

  final VoidCallback _onDelete;

  static bool _isFocusedInEditableText() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    if (focusContext.widget is EditableText) return true;
    return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  bool isEnabled(_DeleteSelectedIntent intent) => !_isFocusedInEditableText();

  @override
  Object? invoke(_DeleteSelectedIntent intent) {
    _onDelete();
    return null;
  }
}

/// Interactive 2D graph editor page for a single workflow (`/workflows/:id`).
class WorkflowEditorPage extends ConsumerStatefulWidget {
  /// Creates a [WorkflowEditorPage] for [workflowId].
  const new({required this.workflowId, super.key});

  /// ID of the workflow being edited.
  final String workflowId;

  @override
  ConsumerState<WorkflowEditorPage> createState() => _WorkflowEditorPageState();
}

class _WorkflowEditorPageState extends ConsumerState<WorkflowEditorPage>
    with TickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _canvasViewportKey = GlobalKey();

  late final AnimationController _edgeFlowController;
  late final AnimationController _panAnimationController;
  Animation<Matrix4>? _panAnimation;

  String? _draftEdgeSourceNodeId;
  Offset? _draftEdgeStart;
  Offset? _draftEdgeEnd;
  int _lastHandledFocusSeq = 0;
  final FocusNode _editorFocusNode = FocusNode(debugLabel: 'WorkflowEditor');
  ProviderSubscription<AsyncValue<WorkflowEditorState>>? _editorSubscription;

  @override
  void initState() {
    super.initState();
    _edgeFlowController = AnimationController(
      vsync: this,
      duration: HiveMotionTokens.standard.long * 4,
    );
    _panAnimationController = AnimationController(
      vsync: this,
      duration: HiveMotionTokens.standard.medium,
    )..addListener(_onPanTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindEditorSubscription();
    _syncEdgeFlowAnimation();
  }

  @override
  void didUpdateWidget(covariant WorkflowEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workflowId != widget.workflowId) {
      _bindEditorSubscription();
      _syncEdgeFlowAnimation();
    }
  }

  void _bindEditorSubscription() {
    _editorSubscription?.close();
    final provider = workflowEditorControllerProvider(widget.workflowId);
    _editorSubscription = ref.listenManual<AsyncValue<WorkflowEditorState>>(
      provider,
      (_, next) {
        if (!mounted) return;
        _syncEdgeFlowAnimation();
        final focus = next.asData?.value.focusRequest;
        if (focus != null && focus.sequence != _lastHandledFocusSeq) {
          _lastHandledFocusSeq = focus.sequence;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _animateToCanvasPoint(focus.x, focus.y);
          });
        }
      },
    );
  }

  void _syncEdgeFlowAnimation() {
    final editorState = ref
        .read(workflowEditorControllerProvider(widget.workflowId))
        .asData
        ?.value;
    final hasSelectedEdge = editorState?.selectedEdgeId != null;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations || !hasSelectedEdge) {
      if (_edgeFlowController.isAnimating) _edgeFlowController.stop();
    } else if (!_edgeFlowController.isAnimating) {
      _edgeFlowController.repeat();
    }
  }

  @override
  void dispose() {
    _editorSubscription?.close();
    _editorFocusNode.dispose();
    _panAnimationController
      ..removeListener(_onPanTick)
      ..dispose();
    _edgeFlowController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onPanTick() {
    final animation = _panAnimation;
    if (animation != null) {
      _transformationController.value = animation.value;
    }
  }

  void _animateToCanvasPoint(double canvasX, double canvasY) {
    final box =
        _canvasViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final viewportSize = box.size;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final tx = viewportSize.width / 2 - canvasX * currentScale;
    final ty = viewportSize.height / 2 - canvasY * currentScale;
    final target = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(currentScale, currentScale, 1, 1);

    if (MediaQuery.disableAnimationsOf(context)) {
      _transformationController.value = target;
      return;
    }

    _panAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _panAnimationController,
            curve: context.hiveMotion.emphasizedCurve,
          ),
        );
    _panAnimationController
      ..reset()
      ..forward();
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

  String? _findNodeAtPoint(Offset canvasPoint, List<WorkflowNode> nodes) {
    for (final node in nodes.reversed) {
      final rect = Rect.fromLTWH(
        node.position.x,
        node.position.y,
        WorkflowCanvasGeometry.nodeWidth,
        WorkflowCanvasGeometry.nodeHeight,
      );
      if (rect.contains(canvasPoint)) return node.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final elevation = context.hiveElevation;
    final editorProvider = workflowEditorControllerProvider(widget.workflowId);
    final stateAsync = ref.watch(editorProvider);

    return stateAsync.when(
      loading: () => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: context.hiveRadii.panel,
        ),
        child: Center(
          child: HiveSpinner(size: spacing.space4, color: colors.accent),
        ),
      ),
      error: (error, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: context.hiveRadii.panel,
        ),
        child: HiveEmptyState(
          icon: HiveIcons.alert,
          title: l10n.editorLoadErrorTitle,
          message: WorkflowL10n.localizeError(l10n, error),
          action: HiveButton(
            label: l10n.editorBackToWorkflowsAction,
            icon: HiveIcons.collapseRail,
            onPressed: () => const WorkflowsRoute().go(context),
          ),
        ),
      ),
      data: (editorState) {
        final controller = ref.read(editorProvider.notifier);
        final errorCount = editorState.validation.issues
            .where((i) => i.severity == WorkflowValidationSeverity.error)
            .length;
        final warningCount = editorState.validation.issues
            .where((i) => i.severity == WorkflowValidationSeverity.warning)
            .length;

        final errorNodeIds = <String>{
          for (final issue in editorState.validation.issues)
            if (issue.severity == WorkflowValidationSeverity.error &&
                issue.nodeId != null)
              issue.nodeId!,
        };
        final warningNodeIds = <String>{
          for (final issue in editorState.validation.issues)
            if (issue.severity == WorkflowValidationSeverity.warning &&
                issue.nodeId != null)
              issue.nodeId!,
        };
        final errorEdgeIds = <String>{
          for (final issue in editorState.validation.issues)
            if (issue.severity == WorkflowValidationSeverity.error &&
                issue.edgeId != null)
              issue.edgeId!,
        };
        final warningEdgeIds = <String>{
          for (final issue in editorState.validation.issues)
            if (issue.severity == WorkflowValidationSeverity.warning &&
                issue.edgeId != null)
              issue.edgeId!,
        };

        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.delete): _DeleteSelectedIntent(),
            SingleActivator(LogicalKeyboardKey.backspace):
                _DeleteSelectedIntent(),
            SingleActivator(LogicalKeyboardKey.keyS, control: true):
                _SaveWorkflowIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _DeleteSelectedIntent: _DeleteSelectedAction(
                controller.deleteSelected,
              ),
              _SaveWorkflowIntent: CallbackAction<_SaveWorkflowIntent>(
                onInvoke: (_) {
                  unawaited(controller.save());
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _editorFocusNode,
              autofocus: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildToolbar(
                    context: context,
                    l10n: l10n,
                    colors: colors,
                    spacing: spacing,
                    typography: typography,
                    elevation: elevation,
                    editorState: editorState,
                    controller: controller,
                    errorCount: errorCount,
                    warningCount: warningCount,
                  ),
                  SizedBox(height: spacing.space2),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _buildCanvas(
                            context: context,
                            l10n: l10n,
                            colors: colors,
                            spacing: spacing,
                            typography: typography,
                            elevation: elevation,
                            editorState: editorState,
                            controller: controller,
                            errorNodeIds: errorNodeIds,
                            warningNodeIds: warningNodeIds,
                            errorEdgeIds: errorEdgeIds,
                            warningEdgeIds: warningEdgeIds,
                          ),
                        ),
                        SizedBox(width: spacing.space2),
                        WorkflowInspectorPanel(
                          state: editorState,
                          onUpdateMetadata: controller.updateWorkflowMetadata,
                          onUpdateNodeLabel: controller.updateNodeLabel,
                          onToggleEntryNode: controller.setEntryNode,
                          onDeleteNode: controller.deleteNode,
                          onUpdateEdge: controller.updateEdge,
                          onDeleteEdge: controller.deleteEdge,
                          onFocusIssue: controller.focusIssue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar({
    required BuildContext context,
    required AppLocalizations l10n,
    required HiveColors colors,
    required HiveSpacing spacing,
    required HiveTypography typography,
    required HiveElevation elevation,
    required WorkflowEditorState editorState,
    required WorkflowEditorController controller,
    required int errorCount,
    required int warningCount,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: context.hiveRadii.panel,
        border: Border.all(
          color: colors.borderSubtle,
          width: elevation.hairline,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.space3,
          vertical: spacing.space2,
        ),
        child: Row(
          children: <Widget>[
            HiveIconButton(
              key: const Key('editor_back_button'),
              icon: HiveIcons.collapseRail,
              semanticLabel: l10n.editorBackAction,
              onPressed: () => const WorkflowsRoute().go(context),
            ),
            SizedBox(width: spacing.space2),
            Expanded(
              child: Text(
                editorState.workflow.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.titleSmall.copyWith(color: colors.onSurface),
              ),
            ),
            if (editorState.saveFailure != null) ...<Widget>[
              HiveBadge(
                label: WorkflowL10n.localizeFailure(
                  l10n,
                  editorState.saveFailure!,
                ),
                tone: HiveBadgeTone.danger,
                icon: HiveIcons.alert,
              ),
              SizedBox(width: spacing.space1),
            ],
            HiveBadge(
              key: const Key('editor_dirty_badge'),
              label: editorState.isDirty
                  ? l10n.editorUnsavedBadge
                  : l10n.editorSavedBadge,
              tone: editorState.isDirty
                  ? HiveBadgeTone.warning
                  : HiveBadgeTone.neutral,
            ),
            SizedBox(width: spacing.space1),
            HiveBadge(
              key: const Key('editor_validation_badge'),
              label: errorCount > 0
                  ? l10n.editorValidationErrorsCount(errorCount)
                  : warningCount > 0
                  ? l10n.editorValidationWarningsCount(warningCount)
                  : l10n.editorValidationValid,
              tone: errorCount > 0
                  ? HiveBadgeTone.danger
                  : warningCount > 0
                  ? HiveBadgeTone.warning
                  : HiveBadgeTone.success,
              icon: errorCount > 0 || warningCount > 0
                  ? HiveIcons.alert
                  : HiveIcons.check,
            ),
            SizedBox(width: spacing.space2),
            HiveButton(
              key: const Key('editor_add_node_button'),
              label: l10n.editorAddNodeAction,
              icon: HiveIcons.add,
              variant: HiveButtonVariant.secondary,
              onPressed: () {
                final nextNumber = editorState.workflow.nodes.length + 1;
                controller.addNode(
                  defaultLabel: l10n.editorDefaultNodeLabel(nextNumber),
                );
              },
            ),
            SizedBox(width: spacing.space1),
            HiveButton(
              key: const Key('editor_save_button'),
              label: editorState.isSaving
                  ? l10n.editorSavingAction
                  : l10n.editorSaveAction,
              icon: HiveIcons.check,
              loading: editorState.isSaving,
              onPressed: editorState.isSaving
                  ? null
                  : () => unawaited(controller.save()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas({
    required BuildContext context,
    required AppLocalizations l10n,
    required HiveColors colors,
    required HiveSpacing spacing,
    required HiveTypography typography,
    required HiveElevation elevation,
    required WorkflowEditorState editorState,
    required WorkflowEditorController controller,
    required Set<String> errorNodeIds,
    required Set<String> warningNodeIds,
    required Set<String> errorEdgeIds,
    required Set<String> warningEdgeIds,
  }) {
    final nodes = editorState.workflow.nodes;
    final edges = editorState.workflow.edges;

    return DecoratedBox(
      key: _canvasViewportKey,
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  _editorFocusNode.requestFocus();
                  final hitEdgeId = WorkflowCanvasGeometry.hitTestEdge(
                    point: details.localPosition,
                    nodes: nodes,
                    edges: edges,
                  );
                  if (hitEdgeId != null) {
                    controller.selectEdge(hitEdgeId);
                  } else {
                    controller.clearSelection();
                  }
                },
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
                        child: AnimatedBuilder(
                          animation: _edgeFlowController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: WorkflowEdgesPainter(
                                nodes: nodes,
                                edges: edges,
                                selectedEdgeId: editorState.selectedEdgeId,
                                errorEdgeIds: errorEdgeIds,
                                warningEdgeIds: warningEdgeIds,
                                colors: colors,
                                typography: typography,
                                flowPhase: _edgeFlowController.value,
                                draftStart: _draftEdgeStart,
                                draftEnd: _draftEdgeEnd,
                              ),
                            );
                          },
                        ),
                      ),
                      for (final node in nodes)
                        Positioned(
                          key: Key('canvas_node_${node.id}'),
                          left: node.position.x,
                          top: node.position.y,
                          child: WorkflowNodeCard(
                            node: node,
                            isSelected: editorState.selectedNodeId == node.id,
                            isEntryNode:
                                editorState.workflow.entryNodeId == node.id,
                            hasError: errorNodeIds.contains(node.id),
                            hasWarning: warningNodeIds.contains(node.id),
                            onTap: () {
                              _editorFocusNode.requestFocus();
                              controller.selectNode(node.id);
                            },
                            onDragDelta: (delta) => controller.moveNode(
                              node.id,
                              delta.dx,
                              delta.dy,
                            ),
                            onPortDragStart: (_) {
                              final start =
                                  WorkflowCanvasGeometry.outputPortCenter(node);
                              setState(() {
                                _draftEdgeSourceNodeId = node.id;
                                _draftEdgeStart = start;
                                _draftEdgeEnd = start;
                              });
                            },
                            onPortDragUpdate: (details) {
                              setState(() {
                                _draftEdgeEnd =
                                    (_draftEdgeEnd ??
                                        WorkflowCanvasGeometry.outputPortCenter(
                                          node,
                                        )) +
                                    details.delta;
                              });
                            },
                            onPortDragEnd: (_) {
                              final sourceId = _draftEdgeSourceNodeId;
                              final dropPoint = _draftEdgeEnd;
                              setState(() {
                                _draftEdgeSourceNodeId = null;
                                _draftEdgeStart = null;
                                _draftEdgeEnd = null;
                              });
                              if (sourceId == null || dropPoint == null) return;
                              final targetId = _findNodeAtPoint(
                                dropPoint,
                                nodes,
                              );
                              if (targetId != null) {
                                controller.addEdge(
                                  sourceNodeId: sourceId,
                                  targetNodeId: targetId,
                                );
                              }
                            },
                          ),
                        ),
                    ],
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
    );
  }
}
