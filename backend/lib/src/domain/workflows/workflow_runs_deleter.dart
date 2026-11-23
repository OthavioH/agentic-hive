import 'package:agentic_hive_backend/src/core/result.dart';

/// Deletes every run of one workflow (rules R1–R5 of #103).
abstract interface class WorkflowRunsDeleter {
  /// Deletes all runs of [workflowId] in [workspaceId]'s scope (`null` =
  /// global workflow: runs in any workspace) and cleans their artifacts.
  ///
  /// Returns the number of deleted runs, or `WorkflowHasActiveRunsFailure`
  /// when any of them is active, in which case nothing is deleted.
  Future<Result<int>> deleteRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
  });
}
