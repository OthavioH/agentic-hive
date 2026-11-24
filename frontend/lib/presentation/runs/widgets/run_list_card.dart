import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Card representing one parent, standalone, or nested child run in `RunsPage`.
class RunListCard extends StatelessWidget {
  /// Creates a [RunListCard].
  const new({
    required this.run,
    required this.isBusy,
    required this.onOpen,
    required this.onDelete,
    this.childCount = 0,
    this.expanded = false,
    this.indented = false,
    this.onToggleChildren,
    super.key,
  });

  /// Summary of the run displayed in this row.
  final RunSummary run;

  /// Whether this run is currently undergoing deletion.
  final bool isBusy;

  /// Number of loaded child runs under this run (`0` for child or leaf rows).
  final int childCount;

  /// Whether the child runs under this parent are currently expanded.
  final bool expanded;

  /// Whether this row is rendered indented as a child run.
  final bool indented;

  /// Opens the run detail page for [run].
  final VoidCallback onOpen;

  /// Initiates deletion of [run].
  final VoidCallback onDelete;

  /// Expands or collapses loaded child runs when [childCount] > 0.
  final VoidCallback? onToggleChildren;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final nodeStatus = RunL10n.nodeStatusFor(run.status);
    final statusLabel = RunL10n.localizeStatus(l10n, run.status);

    return Padding(
      padding: EdgeInsets.only(left: indented ? spacing.space8 : 0),
      child: HiveCard(
        key: Key('run_card_${run.id}'),
        surface: HiveCardSurface.surface2,
        semanticLabel: '${run.workflowName} - $statusLabel',
        onPressed: onOpen,
        child: Row(
          children: <Widget>[
            HiveStatusDot(
              status: nodeStatus,
              semanticLabel: statusLabel,
              size: spacing.space2,
            ),
            SizedBox(width: spacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          run.workflowName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.titleSmall.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.space2),
                      HiveBadge(
                        label: statusLabel,
                        tone: RunL10n.badgeToneFor(run.status),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.spaceHalf),
                  Wrap(
                    spacing: spacing.space3,
                    runSpacing: spacing.spaceHalf,
                    children: <Widget>[
                      Text(
                        RunL10n.formatTimestamp(run.startedAt),
                        style: typography.mono.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
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
                      Text(
                        l10n.runsCheckpointCount(run.checkpointCount),
                        style: typography.label.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                      if (childCount > 0)
                        Text(
                          l10n.runsChildCount(childCount),
                          key: Key('run_children_count_${run.id}'),
                          style: typography.label.copyWith(
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (childCount > 0) ...<Widget>[
              SizedBox(width: spacing.space2),
              HiveIconButton(
                key: Key('run_children_toggle_${run.id}'),
                icon: HiveIcons.chevronDown,
                semanticLabel: expanded
                    ? l10n.runsChildrenCollapseTooltip
                    : l10n.runsChildrenExpandTooltip,
                onPressed: onToggleChildren,
              ),
            ],
            if (!run.status.isActive) ...<Widget>[
              SizedBox(width: childCount > 0 ? spacing.space1 : spacing.space2),
              if (isBusy)
                HiveSpinner(size: spacing.space3, color: colors.accent)
              else
                HiveIconButton(
                  key: Key('run_delete_${run.id}'),
                  icon: HiveIcons.delete,
                  semanticLabel: l10n.runsDeleteTooltip,
                  onPressed: onDelete,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
