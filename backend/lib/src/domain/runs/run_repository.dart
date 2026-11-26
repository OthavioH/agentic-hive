import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persistence contract for workflow execution [Run]s.
abstract interface class RunRepository {
  /// Persists a new [run].
  Future<Result<Run>> create(Run run);

  /// Loads a run by [id], or returns `NotFoundFailure`.
  Future<Result<Run>> getById(String id);

  /// Loads every existing run whose id is in [ids], keyed by id.
  Future<Result<Map<String, Run>>> getByIds(Iterable<String> ids);

  /// Lists [RunSummary] items ordered by `startedAt DESC`, with optional
  /// [status], [workflowId], and [workspaceId] filters and pagination.
  Future<Result<({List<RunSummary> items, int total})>> list({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int limit = 50,
    int offset = 0,
  });

  /// Lists all runs currently in [status], ordered by `startedAt ASC`.
  Future<Result<List<Run>>> listByStatus(RunStatus status);

  /// Lists the child runs of [parentRunId] ordered by `startedAt ASC`;
  /// with [parentNodeId] only those started by that fan-out node.
  Future<Result<List<Run>>> listChildren(
    String parentRunId, {
    String? parentNodeId,
  });

  /// Counts runs currently in [status] whose `finishedAt` timestamp is non-null
  /// and at or after [finishedSince] (inclusive).
  Future<Result<int>> countByStatusFinishedSince(
    RunStatus status, {
    required DateTime finishedSince,
  });

  /// Updates the [status] (and optional [finishedAt] and [errorMessage]) of
  /// run [id].
  ///
  /// Set [clearFinishedAt] or [clearErrorMessage] to `true` to reset those
  /// columns to `null` (for example when retrying cancellation on a
  /// `cancellationUncertain` run).
  Future<Result<Run>> updateStatus(
    String id, {
    required RunStatus status,
    DateTime? finishedAt,
    String? errorMessage,
    bool clearFinishedAt = false,
    bool clearErrorMessage = false,
  });

  /// Atomically transitions [runId] from `running` to `interrupted` and
  /// appends a `run.interrupted` event inside a single transaction.
  ///
  /// Returns `NotFoundFailure` if the run does not exist or is no longer
  /// `running`.
  Future<Result<Run>> markInterruptedWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  });

  /// Atomically transitions [runId] from `cancelling` to
  /// `cancellationUncertain` and appends a `run.cancellation_uncertain` event
  /// inside a single transaction.
  ///
  /// Returns `NotFoundFailure` if the run does not exist or is no longer
  /// `cancelling`.
  Future<Result<Run>> markCancellationUncertainWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  });

  /// Atomically deletes non-active run [id] and every child run
  /// (`parentRunId == id`), cascading checkpoints, events, snapshots and
  /// pauses.
  /// Returns the deleted ids, children first (oldest first) and [id] last.
  ///
  /// Returns `ConflictFailure` when the run, or any of its children, is active
  /// (`running`, `paused`, or `cancelling`), or `NotFoundFailure` when [id]
  /// does not exist. Nothing is deleted on failure.
  Future<Result<List<String>>> delete(String id);

  /// Atomically deletes every run of [workflowId] and the child runs of every
  /// deleted matching run (cascading checkpoints, events, snapshots and pauses)
  /// and returns their ids (matching runs oldest first, then their children
  /// oldest first).
  ///
  /// With [workspaceId] only runs of that workspace match; without it runs of
  /// every workspace match. When any matching run or any child of a matching
  /// run is active (`running`, `paused` or `cancelling`) nothing is deleted and
  /// the result is `WorkflowHasActiveRunsFailure` listing the active runs,
  /// oldest first.
  ///
  /// Runs whose id is in [orphanIds] (and that match [workflowId] and the
  /// scope) are excluded from the active check and from deletion; in the same
  /// transaction their `workflowId` is set to `null` and their children are
  /// kept. An orphan child of a deleted parent is kept with `workflowId`,
  /// `parentRunId` and `parentNodeId` cleared. Nothing is orphaned when the
  /// result is a failure.
  Future<Result<List<String>>> deleteAllOfWorkflow(
    String workflowId, {
    String? workspaceId,
    Set<String> orphanIds = const {},
  });
}
