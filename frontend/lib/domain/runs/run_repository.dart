import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for querying and deleting workflow runs, event logs,
/// and checkpoints.
abstract interface class RunRepository {
  /// Returns paginated run summaries matching optional [status] and
  /// [workflowId] filters.
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  });

  /// Fetches a single run by [id].
  Future<Result<Run>> getRun(String id);

  /// Fetches chronological events for run [id], optionally starting after
  /// [afterSequence].
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  });

  /// Fetches all checkpoints recorded for run [id].
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id);

  /// Deletes a non-active run identified by [id].
  Future<Result<void>> deleteRun(String id);
}
