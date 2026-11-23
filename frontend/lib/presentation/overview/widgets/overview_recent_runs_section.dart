import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_section_header.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Compact Recent Runs list (up to 5 non-active runs) on Overview.
class OverviewRecentRunsSection extends StatelessWidget {
  /// Creates an [OverviewRecentRunsSection].
  const new({
    required this.runs,
    required this.onViewAll,
    required this.onOpenRun,
    super.key,
  });

  /// Recent finished/interrupted runs (capped at 5).
  final List<RunSummary> runs;

  /// Called when "View all" is pressed.
  final VoidCallback onViewAll;

  /// Called when a recent run card is pressed.
  final ValueChanged<String> onOpenRun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final visibleRuns = runs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OverviewSectionHeader(
          title: l10n.overviewSectionRecentRuns,
          actionLabel: l10n.overviewViewAllAction,
          actionKey: const Key('overview_recent_runs_view_all'),
          onAction: onViewAll,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.space2,
          children: <Widget>[
            for (final run in visibleRuns)
              HiveCard(
                key: ValueKey<String>('overview_recent_run_${run.id}'),
                semanticLabel: l10n.overviewOpenRunSemanticLabel(
                  run.workflowName,
                ),
                onPressed: () => onOpenRun(run.id),
                child: Row(
                  spacing: spacing.space2,
                  children: <Widget>[
                    HiveStatusDot(
                      status: RunL10n.nodeStatusFor(run.status),
                      semanticLabel: RunL10n.localizeStatus(l10n, run.status),
                    ),
                    Expanded(
                      child: Text(
                        run.workflowName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.labelLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    HiveBadge(
                      label: RunL10n.localizeStatus(l10n, run.status),
                      tone: RunL10n.badgeToneFor(run.status),
                    ),
                    Text(
                      RunL10n.formatDuration(
                        l10n,
                        run.status,
                        run.startedAt,
                        run.finishedAt,
                      ),
                      style: typography.mono.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
