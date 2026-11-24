import 'package:agentic_hive_frontend/domain/runs/fan_out_progress.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Formats the localized progress summary line for [progress].
String fanOutProgressText(AppLocalizations l10n, FanOutProgress progress) {
  return progress.failed > 0
      ? l10n.runDetailFanOutProgress(
          progress.done,
          progress.total,
          progress.failed,
        )
      : l10n.runDetailFanOutProgressNoFailures(progress.done, progress.total);
}

/// Inspector panel listing the child runs and status summary of a fan-out node.
class FanOutChildrenPanel extends StatelessWidget {
  /// Creates a [FanOutChildrenPanel].
  const new({
    required this.nodeStatus,
    required this.progress,
    required this.isLoading,
    required this.loadFailed,
    required this.failureMessage,
    required this.onOpenRun,
    required this.onRetry,
    super.key,
  });

  /// Current status of the inspected fan-out node.
  final HiveNodeStatus nodeStatus;

  /// Computed progress for the fan-out node, or `null` while loading/failing.
  final FanOutProgress? progress;

  /// Whether the initial child runs fetch is still in progress.
  final bool isLoading;

  /// Whether loading child runs failed.
  final bool loadFailed;

  /// Backend failure message for the failed-before-start state, if any.
  final String? failureMessage;

  /// Opens a child run's detail page by run ID.
  final ValueChanged<String> onOpenRun;

  /// Retries loading child runs after a failure.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;

    return HiveCard(
      surface: HiveCardSurface.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.runDetailFanOutPanelTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space2),
          Expanded(
            child: _buildBody(context, l10n, spacing, colors, typography),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    HiveSpacing spacing,
    HiveColors colors,
    HiveTypography typography,
  ) {
    if (isLoading && progress == null) {
      return Center(
        child: HiveSpinner(
          key: const Key('fan_out_loading'),
          size: spacing.space4,
          color: colors.accent,
        ),
      );
    }

    if (loadFailed) {
      return Align(
        alignment: Alignment.topCenter,
        child: HiveBanner(
          key: const Key('fan_out_load_error'),
          tone: HiveFeedbackTone.danger,
          title: l10n.runDetailFanOutLoadError,
          actions: <Widget>[
            HiveButton(
              key: const Key('fan_out_retry_button'),
              label: l10n.runsRetryAction,
              variant: HiveButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }

    final current = progress;
    if (current == null) {
      return const SizedBox.shrink();
    }

    if (current.emptyList) {
      return Text(
        l10n.runDetailFanOutNoItems,
        key: const Key('fan_out_empty_note'),
        style: typography.body.copyWith(color: colors.onSurfaceMuted),
      );
    }

    if (nodeStatus == HiveNodeStatus.failed &&
        current.isEmpty &&
        !current.emptyList) {
      return Align(
        alignment: Alignment.topCenter,
        child: HiveBanner(
          key: const Key('fan_out_failed_banner'),
          tone: HiveFeedbackTone.danger,
          title: l10n.runDetailFanOutFailedTitle,
          message: failureMessage ?? l10n.runDetailFanOutFailedGeneric,
        ),
      );
    }

    if (current.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: spacing.space2,
          runSpacing: spacing.space1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              fanOutProgressText(l10n, current),
              key: const Key('fan_out_progress_text'),
              style: typography.body.copyWith(color: colors.onSurface),
            ),
            if (current.needsHuman > 0)
              HiveBadge(
                key: const Key('fan_out_needs_you_badge'),
                tone: HiveBadgeTone.warning,
                icon: HiveIcons.pause,
                label: l10n.runDetailFanOutNeedsYou(current.needsHuman),
              ),
          ],
        ),
        SizedBox(height: spacing.space2),
        Expanded(
          child: ListView.separated(
            itemCount: current.items.length,
            separatorBuilder: (_, _) => SizedBox(height: spacing.space2),
            itemBuilder: (context, index) {
              final item = current.items[index];
              final name = item.name.isEmpty
                  ? l10n.runDetailFanOutItemFallbackName(item.index + 1)
                  : item.name;
              final statusLabel = RunL10n.localizeStatus(l10n, item.status);
              return HiveCard(
                key: Key('fan_out_child_${item.index}'),
                surface: HiveCardSurface.surface2,
                semanticLabel: l10n.runDetailFanOutChildSemantic(
                  name,
                  statusLabel,
                ),
                onPressed: item.isOpenable
                    ? () => onOpenRun(item.runId!)
                    : null,
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: <Widget>[
                      HiveStatusDot(
                        status: RunL10n.nodeStatusFor(item.status),
                        semanticLabel: statusLabel,
                        size: spacing.space2,
                      ),
                      SizedBox(width: spacing.space2),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.titleSmall.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.space2),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth / 2,
                        ),
                        child: Wrap(
                          spacing: spacing.space1,
                          runSpacing: spacing.spaceHalf,
                          alignment: WrapAlignment.end,
                          children: <Widget>[
                            HiveBadge(
                              label: statusLabel,
                              tone: RunL10n.badgeToneFor(item.status),
                            ),
                            if (item.deleted)
                              HiveBadge(
                                key: Key('fan_out_child_deleted_${item.index}'),
                                label: l10n.runDetailFanOutDeleted,
                              )
                            else if (item.runId == null)
                              HiveBadge(
                                label: l10n.runDetailFanOutNotStarted,
                                tone: HiveBadgeTone.danger,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
