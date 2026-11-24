import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/pauses/utils/pause_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Master list pane showing pending pauses ordered by creation time.
class PauseListPane extends StatelessWidget {
  /// Creates a [PauseListPane].
  const new({
    required this.pauses,
    required this.selectedPauseId,
    required this.onSelectPause,
    this.now,
    super.key,
  });

  /// Pending pauses to display.
  final List<Pause> pauses;

  /// Currently selected pause ID, if any.
  final String? selectedPauseId;

  /// Called when a pause card is activated.
  final ValueChanged<String> onSelectPause;

  /// Reference timestamp for relative waiting-time labels.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    return ListView.separated(
      padding: EdgeInsets.all(spacing.space2),
      itemCount: pauses.length,
      separatorBuilder: (_, _) => SizedBox(height: spacing.space1),
      itemBuilder: (context, index) {
        final pause = pauses[index];
        final isSelected = pause.id == selectedPauseId;
        final kindText = pause.kind.label(l10n);
        final waitingText = PauseL10n.formatWaitingTime(
          l10n,
          pause.createdAt,
          now: now,
        );

        return Semantics(
          selected: isSelected,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: context.hiveRadii.card,
              border: isSelected
                  ? Border.all(
                      color: colors.accent,
                      width: context.hiveElevation.hairline,
                    )
                  : null,
            ),
            child: HiveCard(
              key: ValueKey<String>('pause_list_item_${pause.id}'),
              surface: HiveCardSurface.surface2,
              semanticLabel: l10n.pausesListItemSemantic(
                kindText,
                pause.workflowName,
                pause.nodeLabel,
                waitingText,
              ),
              onPressed: () => onSelectPause(pause.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      HiveStatusDot(
                        status: HiveNodeStatus.paused,
                        semanticLabel: l10n.pausesStatusPending,
                      ),
                      SizedBox(width: spacing.space1),
                      HiveBadge(label: kindText, tone: pause.kind.badgeTone),
                      const Spacer(),
                      Text(
                        waitingText,
                        style: typography.label.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.space1),
                  Text(
                    pause.workflowName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.labelLarge.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  SizedBox(height: spacing.spaceHalf),
                  Text(
                    pause.nodeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                  if (pause.parentRunId != null) ...<Widget>[
                    SizedBox(height: spacing.spaceHalf),
                    Text(
                      l10n.pausesChildOfRun(_shortId(pause.parentRunId!)),
                      key: ValueKey<String>('pause_parent_link_${pause.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.label.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
