import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_section_header.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Overview Metrics section displaying hierarchical focal and compact
/// [HiveMetricTile]s.
class OverviewMetricsSection extends StatelessWidget {
  /// Creates an [OverviewMetricsSection].
  const new({required this.metrics, super.key});

  /// Aggregate operational counts from the overview snapshot.
  final OverviewMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OverviewSectionHeader(title: l10n.overviewSectionMetrics),
        HiveMetricTile(
          key: const Key('overview_metric_active_runs'),
          value: '${metrics.activeRunsCount}',
          label: l10n.overviewMetricActiveRuns,
          size: HiveMetricTileSize.focal,
        ),
        SizedBox(height: spacing.space2),
        Row(
          spacing: spacing.space2,
          children: <Widget>[
            Expanded(
              child: HiveMetricTile(
                key: const Key('overview_metric_active_nodes'),
                value: '${metrics.activeNodesCount}',
                label: l10n.overviewMetricActiveNodes,
              ),
            ),
            Expanded(
              child: HiveMetricTile(
                key: const Key('overview_metric_pending_pauses'),
                value: '${metrics.pendingPausesCount}',
                label: l10n.overviewMetricPendingPauses,
                tone: metrics.pendingPausesCount > 0
                    ? HiveFeedbackTone.warning
                    : null,
                semanticLabel: metrics.pendingPausesCount > 0
                    ? l10n.overviewMetricNeedsAttentionSemantic(
                        l10n.overviewMetricPendingPauses,
                        metrics.pendingPausesCount,
                      )
                    : null,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.space2),
        Row(
          spacing: spacing.space2,
          children: <Widget>[
            Expanded(
              child: HiveMetricTile(
                key: const Key('overview_metric_succeeded_24h'),
                value: '${metrics.succeededLast24hCount}',
                label: l10n.overviewMetricSucceeded24h,
                tone: HiveFeedbackTone.success,
              ),
            ),
            Expanded(
              child: HiveMetricTile(
                key: const Key('overview_metric_failed_24h'),
                value: '${metrics.failedLast24hCount}',
                label: l10n.overviewMetricFailed24h,
                tone: metrics.failedLast24hCount > 0
                    ? HiveFeedbackTone.danger
                    : null,
                semanticLabel: metrics.failedLast24hCount > 0
                    ? l10n.overviewMetricNeedsAttentionSemantic(
                        l10n.overviewMetricFailed24h,
                        metrics.failedLast24hCount,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
