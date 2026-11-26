import 'dart:async';

import 'package:agentic_hive_frontend/domain/workspace/restore_availability.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/snapshots_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/utils/snapshot_l10n.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/restore_snapshot_dialog.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/snapshot_card.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Chronological list of workspace snapshots for a run, with expandable
/// changed files and a confirmed Restore action.
class SnapshotsPanel extends ConsumerStatefulWidget {
  /// Creates the panel for run [runId].
  const new({
    required this.runId,
    required this.workspaceRoot,
    required this.runStatus,
    required this.nodeLabels,
    super.key,
  });

  /// ID of the run whose snapshots are shown.
  final String runId;

  /// Root folder of the run's workspace, used for the git capability check.
  final String workspaceRoot;

  /// Current status of the run; restore is unavailable while `running`.
  final RunStatus runStatus;

  /// Node display names keyed by node ID.
  final Map<String, String> nodeLabels;

  @override
  ConsumerState<SnapshotsPanel> createState() => _SnapshotsPanelState();
}

class _SnapshotsPanelState extends ConsumerState<SnapshotsPanel> {
  bool _showRestored = false;

  SnapshotsControllerProvider get _provider =>
      snapshotsControllerProvider(widget.runId, widget.workspaceRoot);

  String _nodeLabel(AppLocalizations l10n, Snapshot snapshot) {
    final nodeId = snapshot.nodeId;
    if (nodeId == null) return l10n.snapshotNodeUnknown;
    return widget.nodeLabels[nodeId] ?? nodeId;
  }

  Future<void> _confirmRestore(Snapshot snapshot) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await RestoreSnapshotDialog.show(
      context,
      snapshot: snapshot,
      nodeLabel: _nodeLabel(l10n, snapshot),
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(_provider.notifier).restore(snapshot.id);
    if (!mounted) return;
    setState(() => _showRestored = ok);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final stateAsync = ref.watch(_provider);

    return HiveCard(
      surface: HiveCardSurface.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.snapshotsTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space2),
          Expanded(
            child: stateAsync.when(
              loading: () => Center(
                child: HiveSpinner(size: spacing.space4, color: colors.accent),
              ),
              error: (error, _) => HiveEmptyState(
                icon: HiveIcons.alert,
                title: l10n.snapshotsLoadErrorTitle,
                message: RunL10n.localizeError(l10n, error),
                action: HiveButton(
                  key: const Key('snapshots_retry_button'),
                  label: l10n.runsRetryAction,
                  icon: HiveIcons.refresh,
                  onPressed: () =>
                      unawaited(ref.read(_provider.notifier).refresh()),
                ),
              ),
              data: _buildData,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildData(SnapshotsState state) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final availability = RestoreAvailability.resolve(
      status: widget.runStatus,
      capabilities: state.capabilities,
    );
    final notice = SnapshotL10n.restoreNotice(l10n, availability);
    final failure = state.restoreFailure;

    if (state.snapshots.isEmpty) {
      return HiveEmptyState(
        icon: HiveIcons.clock,
        title: l10n.snapshotsTitle,
        message: l10n.snapshotsEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (notice != null) ...<Widget>[
          HiveBanner(
            key: const Key('snapshots_restore_notice'),
            tone: HiveFeedbackTone.info,
            title: notice,
          ),
          SizedBox(height: spacing.space2),
        ],
        if (failure != null) ...<Widget>[
          HiveBanner(
            key: const Key('snapshots_restore_failure'),
            tone: HiveFeedbackTone.danger,
            title: l10n.snapshotsRestoreFailedTitle,
            message: SnapshotL10n.localizeRestoreFailure(l10n, failure),
            liveRegion: true,
            onDismiss: () =>
                ref.read(_provider.notifier).dismissRestoreFailure(),
            dismissSemanticLabel: l10n.snapshotsDismissTooltip,
          ),
          SizedBox(height: spacing.space2),
        ] else if (_showRestored) ...<Widget>[
          HiveBanner(
            key: const Key('snapshots_restore_success'),
            tone: HiveFeedbackTone.success,
            title: l10n.snapshotsRestoreSuccessTitle,
            message: l10n.snapshotsRestoreSuccessMessage,
            liveRegion: true,
            onDismiss: () => setState(() => _showRestored = false),
            dismissSemanticLabel: l10n.snapshotsDismissTooltip,
          ),
          SizedBox(height: spacing.space2),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: state.snapshots.length,
            separatorBuilder: (_, _) => SizedBox(height: spacing.space2),
            itemBuilder: (context, index) {
              final snapshot = state.snapshots[index];
              return SnapshotCard(
                snapshot: snapshot,
                nodeLabel: _nodeLabel(l10n, snapshot),
                expanded: state.expandedSnapshotIds.contains(snapshot.id),
                diff: state.diffs[snapshot.id],
                restoreEnabled:
                    availability.isAvailable &&
                    state.restoringSnapshotId == null,
                restoring: state.restoringSnapshotId == snapshot.id,
                onToggleExpanded: () => unawaited(
                  ref.read(_provider.notifier).toggleExpanded(snapshot.id),
                ),
                onRestore: () => unawaited(_confirmRestore(snapshot)),
              );
            },
          ),
        ),
      ],
    );
  }
}
