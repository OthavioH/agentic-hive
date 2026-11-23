import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_delete_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Status badge of a workflow row while its deletion runs: the phase and the
/// stop counters when they are known. A live region, so it is announced.
class WorkflowDeletingBadge extends StatelessWidget {
  /// Creates a [WorkflowDeletingBadge] for the row [workflowId].
  const new({required this.workflowId, this.progress, super.key});

  /// Id of the workflow the badge belongs to; keys the badge for tests.
  final String workflowId;

  /// Latest progress of the deletion; `null` before the first update.
  final WorkflowDeletionProgressView? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = progress;
    final label = switch (current?.phase) {
      WorkflowDeletionPhase.stoppingRuns => l10n.workflowsDeletingStoppingRuns(
        current!.runsStopped,
        current.runsToStop,
      ),
      WorkflowDeletionPhase.deletingRuns => l10n.workflowsDeletingRemovingRuns,
      WorkflowDeletionPhase.done || null => l10n.workflowsDeletingStatus,
    };
    return Semantics(
      key: Key('workflow_deleting_$workflowId'),
      container: true,
      liveRegion: true,
      child: HiveBadge(label: label, tone: HiveBadgeTone.warning),
    );
  }
}
