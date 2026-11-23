import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_delete_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// The status text of a workflow row while its deletion runs; shared by the
/// visible badge and the row's live-region status.
String workflowDeletingLabel(
  AppLocalizations l10n,
  WorkflowDeletionProgressView? progress,
) => switch (progress?.phase) {
  WorkflowDeletionPhase.stoppingRuns => l10n.workflowsDeletingStoppingRuns(
    progress!.runsStopped,
    progress.runsToStop,
  ),
  WorkflowDeletionPhase.deletingRuns => l10n.workflowsDeletingRemovingRuns,
  WorkflowDeletionPhase.done || null => l10n.workflowsDeletingStatus,
};

/// Visible status badge of a deleting workflow row. It is excluded from
/// semantics: the row's busy `HiveCard` announces the same text as its
/// live-region status.
class WorkflowDeletingBadge extends StatelessWidget {
  /// Creates a [WorkflowDeletingBadge] for the row [workflowId].
  const new({required this.workflowId, this.progress, super.key});

  /// Id of the workflow the badge belongs to; keys the badge for tests.
  final String workflowId;

  /// Latest progress of the deletion; `null` before the first update.
  final WorkflowDeletionProgressView? progress;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      key: Key('workflow_deleting_$workflowId'),
      child: HiveBadge(
        label: workflowDeletingLabel(AppLocalizations.of(context)!, progress),
        tone: HiveBadgeTone.warning,
      ),
    );
  }
}
