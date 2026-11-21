import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/snapshots_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/utils/snapshot_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// One snapshot in the Snapshots panel: summary, expandable changed files and
/// the Restore action.
class SnapshotCard extends StatelessWidget {
  /// Creates a card for [snapshot].
  const new({
    required this.snapshot,
    required this.nodeLabel,
    required this.expanded,
    required this.diff,
    required this.restoreEnabled,
    required this.restoring,
    required this.onToggleExpanded,
    required this.onRestore,
    super.key,
  });

  /// Snapshot to render.
  final Snapshot snapshot;

  /// Display name of the node the snapshot was captured for.
  final String nodeLabel;

  /// Whether the changed-file list is expanded.
  final bool expanded;

  /// Load state of the changed-file list, or `null` before it is requested.
  final SnapshotDiffState? diff;

  /// Whether the Restore action may be used.
  final bool restoreEnabled;

  /// Whether this snapshot is currently being restored.
  final bool restoring;

  /// Called to expand or collapse the changed-file list.
  final VoidCallback onToggleExpanded;

  /// Called when the Restore action is activated.
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    return HiveCard(
      key: Key('snapshot_card_${snapshot.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  nodeLabel,
                  style: typography.label.copyWith(color: colors.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: spacing.space2),
              HiveBadge(
                key: Key('snapshot_kind_${snapshot.id}'),
                label: SnapshotL10n.localizeKind(l10n, snapshot.kind),
                tone: SnapshotL10n.toneFor(snapshot.kind),
              ),
            ],
          ),
          SizedBox(height: spacing.space1),
          Text(
            RunL10n.formatTimestamp(snapshot.createdAt),
            style: typography.mono.copyWith(color: colors.onSurfaceMuted),
          ),
          SizedBox(height: spacing.space2),
          Row(
            children: <Widget>[
              HiveDiffStat(
                key: Key('snapshot_stat_${snapshot.id}'),
                added: snapshot.addedCount,
                modified: snapshot.modifiedCount,
                deleted: snapshot.deletedCount,
                semanticLabel: l10n.snapshotDiffStatSemanticLabel(
                  snapshot.addedCount,
                  snapshot.modifiedCount,
                  snapshot.deletedCount,
                ),
              ),
              const Spacer(),
              HiveIconButton(
                key: Key('snapshot_toggle_${snapshot.id}'),
                icon: HiveIcons.chevronDown,
                size: HiveButtonSize.small,
                semanticLabel: expanded
                    ? l10n.snapshotsHideFilesTooltip
                    : l10n.snapshotsShowFilesTooltip,
                onPressed: onToggleExpanded,
              ),
              SizedBox(width: spacing.space1),
              HiveButton(
                key: Key('snapshot_restore_${snapshot.id}'),
                label: restoring
                    ? l10n.snapshotsRestoringAction
                    : l10n.snapshotsRestoreAction,
                variant: HiveButtonVariant.secondary,
                size: HiveButtonSize.small,
                loading: restoring,
                onPressed: restoreEnabled && !restoring ? onRestore : null,
              ),
            ],
          ),
          if (expanded) ...<Widget>[
            SizedBox(height: spacing.space2),
            _ChangedFiles(snapshotId: snapshot.id, diff: diff),
          ],
        ],
      ),
    );
  }
}

class _ChangedFiles extends StatelessWidget {
  const new({required this.snapshotId, required this.diff});

  final String snapshotId;
  final SnapshotDiffState? diff;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    return switch (diff) {
      null || SnapshotDiffLoading() => Center(
        child: HiveSpinner(size: spacing.space3, color: colors.accent),
      ),
      SnapshotDiffFailed() => Text(
        l10n.snapshotsDiffLoadFailed,
        key: Key('snapshot_diff_error_$snapshotId'),
        style: typography.body.copyWith(color: colors.danger),
      ),
      SnapshotDiffLoaded(:final files) when files.isEmpty => Text(
        l10n.snapshotsNoChangedFiles,
        key: Key('snapshot_diff_empty_$snapshotId'),
        style: typography.body.copyWith(color: colors.onSurfaceMuted),
      ),
      SnapshotDiffLoaded(:final files) => Column(
        key: Key('snapshot_files_$snapshotId'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final file in files)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.spaceHalf),
              child: Semantics(
                label:
                    '${SnapshotL10n.localizeChange(l10n, file.changeType)} '
                    '${file.path}',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      SnapshotL10n.diffKindFor(file.changeType).sign,
                      style: typography.mono.copyWith(
                        color: SnapshotL10n.diffKindFor(file.changeType)
                            .tone(colors),
                      ),
                    ),
                    SizedBox(width: spacing.space2),
                    Expanded(
                      child: Text(
                        file.path,
                        style: typography.mono.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    };
  }
}
