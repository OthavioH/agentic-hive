import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector panel displaying live `stdout`/`stderr` output for a node attempt.
class RunOutputPanel extends ConsumerWidget {
  /// Creates a [RunOutputPanel].
  const new({required this.runId, required this.detailState, super.key});

  /// ID of the run being monitored.
  final String runId;

  /// Current run detail state.
  final RunDetailState detailState;

  String? _nodeLabel(String? nodeId) {
    if (nodeId == null) return null;
    for (final node in detailState.run.workflowDefinition.nodes) {
      if (node.id == nodeId) return node.label;
    }
    return nodeId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final controller = ref.read(runDetailControllerProvider(runId).notifier);

    final nodeId = detailState.inspectedNodeId;
    final nodeLabel = _nodeLabel(nodeId);
    final nodeStatus = nodeId != null
        ? (detailState.nodeStatuses[nodeId] ?? HiveNodeStatus.idle)
        : null;

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
          if (detailState.logsTruncated) ...<Widget>[
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
                ? HiveEmptyState(
                    icon: HiveIcons.terminal,
                    title: l10n.runDetailOutputTitle,
                    message: l10n.runDetailOutputSelectNode,
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
