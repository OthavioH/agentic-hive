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

  /// Starts a new run from [request].
  Future<Result<Run>> startRun(StartRunRequest request);

  /// Requests cancellation of an active or `cancellationUncertain` run [id].
  Future<Result<Run>> cancelRun(String id);

  /// Resumes an interrupted run [id] from its latest checkpoint.
  Future<Result<Run>> resumeRun(String id);

  /// Fetches captured `stdout`/`stderr` logs for [nodeId] in run [id].
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  });

  /// Deletes a non-active run identified by [id].
  Future<Result<void>> deleteRun(String id);
}
