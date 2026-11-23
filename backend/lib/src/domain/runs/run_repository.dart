import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persistence contract for workflow execution [Run]s.
abstract interface class RunRepository {
  /// Persists a new [run].
  Future<Result<Run>> create(Run run);

  /// Loads a run by [id], or returns `NotFoundFailure`.
  Future<Result<Run>> getById(String id);

  /// Lists [RunSummary] items ordered by `startedAt DESC`, with optional
  /// filters and pagination.
  Future<Result<({List<RunSummary> items, int total})>> list({
    RunStatus? status,
    String? workflowId,
    int limit = 50,
    int offset = 0,
  });

  /// Lists all runs currently in [status], ordered by `startedAt ASC`.
  Future<Result<List<Run>>> listByStatus(RunStatus status);

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

  /// Atomically deletes a non-active run [id] (cascading its checkpoints and
  /// events).
  ///
  /// Returns `ConflictFailure` when the run is active (`running`, `paused`,
  /// or `cancelling`), or `NotFoundFailure` when [id] does not exist.
  Future<Result<void>> delete(String id);
}
