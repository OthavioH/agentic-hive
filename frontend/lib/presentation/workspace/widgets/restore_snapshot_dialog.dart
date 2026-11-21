import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Confirmation dialog shown before a snapshot restore starts.
class RestoreSnapshotDialog extends StatelessWidget {
  /// Creates a restore confirmation dialog for [snapshot].
  const new({required this.snapshot, required this.nodeLabel, super.key});

  /// Snapshot that would be restored.
  final Snapshot snapshot;

  /// Display name of the node the snapshot was captured for.
  final String nodeLabel;

  /// Shows the dialog and resolves to `true` only when the user confirms.
  static Future<bool> show(
    BuildContext context, {
    required Snapshot snapshot,
    required String nodeLabel,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await HiveDialog.show<bool>(
      context: context,
      barrierLabel: l10n.snapshotsRestoreBarrierLabel,
      builder: (_) =>
          RestoreSnapshotDialog(snapshot: snapshot, nodeLabel: nodeLabel),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    return HiveDialog(
      title: l10n.snapshotsRestoreDialogTitle,
      message: l10n.snapshotsRestoreDialogMessage,
      icon: HiveIcons.alert,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            nodeLabel,
            key: const Key('restore_dialog_node'),
            style: typography.label.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space1),
          Text(
            RunL10n.formatTimestamp(snapshot.createdAt),
            style: typography.mono.copyWith(color: colors.onSurfaceMuted),
          ),
          SizedBox(height: spacing.space2),
          HiveDiffStat(
            added: snapshot.addedCount,
            modified: snapshot.modifiedCount,
            deleted: snapshot.deletedCount,
            semanticLabel: l10n.snapshotDiffStatSemanticLabel(
              snapshot.addedCount,
              snapshot.modifiedCount,
              snapshot.deletedCount,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        HiveButton(
          key: const Key('restore_dialog_cancel'),
          label: l10n.snapshotsRestoreCancel,
          variant: HiveButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        HiveButton(
          key: const Key('restore_dialog_confirm'),
          label: l10n.snapshotsRestoreConfirm,
          variant: HiveButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
