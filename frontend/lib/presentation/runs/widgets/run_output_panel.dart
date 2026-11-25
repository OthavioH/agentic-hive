import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/pty_terminal_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector panel displaying live `stdout`/`stderr` output or an embedded
/// PTY terminal for a node attempt.
class RunOutputPanel extends ConsumerStatefulWidget {
  /// Creates a [RunOutputPanel].
  const new({required this.runId, required this.detailState, super.key});

  /// ID of the run being monitored.
  final String runId;

  /// Current run detail state.
  final RunDetailState detailState;

  @override
  ConsumerState<RunOutputPanel> createState() => _RunOutputPanelState();
}

class _RunOutputPanelState extends ConsumerState<RunOutputPanel> {
  final Set<(String, int)> _activeTerminalSessions = <(String, int)>{};

  WorkflowNode? _findNode(String? nodeId) {
    if (nodeId == null) return null;
    for (final node in widget.detailState.run.workflowDefinition.nodes) {
      if (node.id == nodeId) return node;
    }
    return null;
  }

  static bool _isNodeActive(HiveNodeStatus? status) =>
      status == HiveNodeStatus.running ||
      status == HiveNodeStatus.paused ||
      status == HiveNodeStatus.cancelling;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final detailState = widget.detailState;
    final controller = ref.read(
      runDetailControllerProvider(widget.runId).notifier,
    );

    final nodeId = detailState.inspectedNodeId;
    final node = _findNode(nodeId);
    final nodeLabel = node?.label ?? nodeId;
    final nodeStatus = nodeId != null
        ? (detailState.nodeStatuses[nodeId] ?? HiveNodeStatus.idle)
        : null;

    final isTerminalNode = node?.type == NodeTypeId.terminal;
    final attempt = detailState.selectedAttempt ?? 1;
    final isActive = _isNodeActive(nodeStatus);
    if (nodeId != null && isTerminalNode && isActive) {
      _activeTerminalSessions.add((nodeId, attempt));
    }
    final showTerminal =
        nodeId != null &&
        isTerminalNode &&
        (isActive || _activeTerminalSessions.contains((nodeId, attempt)));

    return HiveCard(
      surface: HiveCardSurface.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (nodeStatus != null) ...<Widget>[
                HiveStatusDot(
                  status: nodeStatus,
                  semanticLabel: RunL10n.localizeNodeStatus(l10n, nodeStatus),
                  size: spacing.space2,
                ),
                SizedBox(width: spacing.space1),
              ],
              Expanded(
                child: Text(
                  nodeLabel ?? l10n.runDetailOutputTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.titleSmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (detailState.followActiveNode)
                HiveBadge(
                  key: const Key('run_output_following_badge'),
                  label: l10n.runDetailFollowActiveBadge,
                  tone: HiveBadgeTone.info,
                )
              else
                HiveButton(
                  key: const Key('run_output_follow_active_button'),
                  label: l10n.runDetailFollowActiveButton,
                  size: HiveButtonSize.small,
                  variant: HiveButtonVariant.secondary,
                  onPressed: () => unawaited(controller.enableFollowActive()),
                ),
            ],
          ),
          if (detailState.availableAttempts.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.space2),
            Row(
              children: <Widget>[
                SizedBox(
                  width: spacing.space8 * 2 + spacing.space4,
                  child: HiveSelect<int>(
                    key: const Key('run_output_attempt_select'),
                    label: l10n.runDetailOutputAttemptLabel,
                    options: <HiveSelectOption<int>>[
                      for (final attempt in detailState.availableAttempts)
                        HiveSelectOption<int>(
                          value: attempt,
                          label: l10n.runDetailOutputAttemptOption(attempt),
                        ),
                    ],
                    value: detailState.selectedAttempt,
                    onChanged: (attempt) =>
                        unawaited(controller.selectAttempt(attempt)),
                  ),
                ),
              ],
            ),
          ],
          if (!showTerminal && detailState.logsTruncated) ...<Widget>[
            SizedBox(height: spacing.space2),
            HiveBadge(
              label: l10n.runDetailOutputTruncatedNotice,
              tone: HiveBadgeTone.warning,
              icon: HiveIcons.alert,
            ),
          ],
          SizedBox(height: spacing.space2),
          Expanded(
            child: nodeId == null
                ? Center(
                    child: SingleChildScrollView(
                      child: HiveEmptyState(
                        icon: HiveIcons.terminal,
                        title: l10n.runDetailOutputTitle,
                        message: l10n.runDetailOutputSelectNode,
                      ),
                    ),
                  )
                : showTerminal
                ? PtyTerminalPanel(
                    key: Key('run_pty_terminal_${nodeId}_$attempt'),
                    runId: widget.runId,
                    nodeId: nodeId,
                    attempt: attempt,
                    nodeLabel: nodeLabel ?? l10n.runDetailOutputTitle,
                    isEnded: !isActive,
                  )
                : detailState.isLoadingLogs && controller.logController.isEmpty
                ? Center(
                    child: HiveSpinner(
                      size: spacing.space4,
                      color: colors.accent,
                    ),
                  )
                : HiveLogStreamViewer(
                    key: Key('run_log_viewer_$nodeId'),
                    controller: controller.logController,
                    semanticLabel: l10n.runDetailOutputTitle,
                    jumpToBottomLabel: l10n.runDetailOutputJumpToBottom,
                    stderrSemanticLabel: l10n.runDetailOutputStderrLabel,
                    emptyLabel: l10n.runDetailOutputEmpty,
                  ),
          ),
        ],
      ),
    );
  }
}
