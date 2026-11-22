import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/overview/utils/overview_l10n.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_section_header.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Active Runs section on the Overview dashboard.
class OverviewActiveRunsSection extends StatelessWidget {
  /// Creates an [OverviewActiveRunsSection].
  const new({
    required this.runs,
    required this.now,
    required this.onViewAll,
    required this.onOpenRun,
    super.key,
  });

  /// Active (`running` or `paused`) runs to display.
  final List<ActiveRunSummary> runs;

  /// Current timestamp for live elapsed duration formatting.
  final DateTime now;

  /// Called when "View all" is pressed.
  final VoidCallback onViewAll;

  /// Called when an active run card is pressed.
  final ValueChanged<String> onOpenRun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OverviewSectionHeader(
          title: l10n.overviewSectionActiveRuns,
          count: runs.length,
          actionLabel: l10n.overviewViewAllAction,
          actionKey: const Key('overview_active_runs_view_all'),
          onAction: onViewAll,
        ),
        if (runs.isEmpty)
          HiveCard(
            child: Text(
              l10n.overviewActiveRunsEmpty,
              style: typography.body.copyWith(color: colors.onSurfaceMuted),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.space2,
            children: <Widget>[
              for (final run in runs)
                _ActiveRunCard(
                  run: run,
                  now: now,
                  onPressed: () => onOpenRun(run.runId),
                ),
            ],
          ),
      ],
    );
  }
}

class _ActiveRunCard extends StatelessWidget {
  const new({required this.run, required this.now, required this.onPressed});

  final ActiveRunSummary run;
  final DateTime now;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final statusLabel = RunL10n.localizeStatus(l10n, run.status);
    final elapsed = OverviewL10n.formatElapsed(run.startedAt, now);

    return HiveCard(
      key: ValueKey<String>('overview_active_run_${run.runId}'),
      semanticLabel: l10n.overviewOpenRunSemanticLabel(run.workflowName),
      onPressed: onPressed,
      child: Row(
        spacing: spacing.space2,
        children: <Widget>[
          HiveStatusDot(
            status: RunL10n.nodeStatusFor(run.status),
            semanticLabel: statusLabel,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.spaceHalf,
              children: <Widget>[
                Text(
                  run.workflowName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.labelLarge.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  l10n.overviewActiveNodeCount(run.activeNodeCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySmall.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          HiveBadge(label: statusLabel, tone: RunL10n.badgeToneFor(run.status)),
          Text(
            elapsed,
            style: typography.mono.copyWith(color: colors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
