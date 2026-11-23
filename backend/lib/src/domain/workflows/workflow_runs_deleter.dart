import 'package:agentic_hive_backend/src/core/result.dart';

/// Outcome of deleting the runs of one workflow.
final class WorkflowRunsDeletion {
  /// Creates a deletion outcome.
  const new({required this.deletedRuns, this.orphanedRuns = const []});

  /// Number of runs deleted.
  final int deletedRuns;

  /// Ids of runs kept with `workflowId` cleared because their cancellation
  /// could not be confirmed (or were already uncertain), oldest first.
  final List<String> orphanedRuns;
}

/// Deletes every run of one workflow (#103, #104).
abstract interface class WorkflowRunsDeleter {
  /// Deletes all runs of [workflowId] in [workspaceId]'s scope (`null` =
  /// global workflow: runs in any workspace) and cleans their artifacts.
  ///
  /// Without [force], returns `WorkflowHasActiveRunsFailure` when any run is
  /// active and deletes nothing. With [force], cancels the active runs, waits
  /// until every cancellation settled, deletes the settled runs and keeps the
  /// unconfirmed ones as orphans. Pre-existing `cancellationUncertain` runs are
  /// also kept as orphans.
  Future<Result<WorkflowRunsDeletion>> deleteRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
    bool force = false,
  });
}
