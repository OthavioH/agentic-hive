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

  /// Updates the [status] (and optional [finishedAt] and [errorMessage]) of
  /// run [id].
  Future<Result<Run>> updateStatus(
    String id, {
    required RunStatus status,
    DateTime? finishedAt,
    String? errorMessage,
  });

  /// Deletes run [id] (cascading its checkpoints and events).
  Future<Result<void>> delete(String id);
}
