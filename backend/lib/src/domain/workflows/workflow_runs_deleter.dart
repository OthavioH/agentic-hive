import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Progress of deleting one workflow's runs (ADR 0027).
final class WorkflowRunsProgress {
  /// Creates a progress snapshot.
  const new({
    required this.phase,
    this.runsToStop = 0,
    this.runsStopped = 0,
    this.runsDeleted = 0,
  });

  /// Current deletion phase.
  final WorkflowDeletionPhase phase;

  /// Number of runs to stop.
  final int runsToStop;

  /// Number of settled run cancellations.
  final int runsStopped;

  /// Number of runs whose artifacts were cleaned.
  final int runsDeleted;
}

/// Receives updates while workflow runs are deleted.
typedef WorkflowRunsProgressListener = void Function(
  WorkflowRunsProgress progress,
);

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
  /// Active runs, oldest first, in the requested workflow scope.
  Future<Result<Map<String, RunStatus>>> activeRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
  });

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
    WorkflowRunsProgressListener? onProgress,
  });
}
