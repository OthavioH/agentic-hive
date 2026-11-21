import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Domain service for querying and managing [Run]s, [Checkpoint]s, and
/// [RunEvent]s.
final class RunService {
  /// Creates a run service.
  new({required this._runs, required this._checkpoints, required this._events});

  final RunRepository _runs;
  final CheckpointRepository _checkpoints;
  final RunEventRepository _events;

  /// Lists runs ordered by `startedAt DESC` with optional filters.
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit <= 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "limit" must be greater than 0.'),
      );
    }
    if (offset < 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "offset" must be >= 0.'),
      );
    }

    final result = await _runs.list(
      status: status,
      workflowId: workflowId,
      limit: limit,
      offset: offset,
    );
    return result.map(
      (page) => RunsListResponse(items: page.items, total: page.total),
    );
  }

  /// Fetches a single run by [id].
  Future<Result<Run>> getRun(String id) => _runs.getById(id);

  /// Lists events for [runId] ordered by `sequence ASC`.
  Future<Result<RunEventsResponse>> getRunEvents(
    String runId, {
    int? afterSequence,
    int? limit,
  }) async {
    if (afterSequence != null && afterSequence < 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "afterSequence" must be >= 0.'),
      );
    }
    if (limit != null && limit <= 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "limit" must be greater than 0.'),
      );
    }

    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    final eventsResult = await _events.listForRun(
      runId,
      afterSequence: afterSequence,
      limit: limit,
    );
    return eventsResult.map(
      (page) =>
          RunEventsResponse(items: page.items, lastSequence: page.lastSequence),
    );
  }

  /// Lists checkpoints for [runId] ordered by `sequence ASC`, or only the
  /// latest checkpoint when [latest] is true.
  Future<Result<RunCheckpointsResponse>> getRunCheckpoints(
    String runId, {
    bool latest = false,
  }) async {
    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    if (latest) {
      final latestResult = await _checkpoints.getLatestForRun(runId);
      return latestResult.map(
        (checkpoint) => RunCheckpointsResponse(
          items: checkpoint == null ? const [] : [checkpoint],
        ),
      );
    }

    final listResult = await _checkpoints.listForRun(runId);
    return listResult.map((items) => RunCheckpointsResponse(items: items));
  }

  /// Deletes a non-active run [id] (cascading its checkpoints and events).
  ///
  /// Returns [ConflictFailure] when the run is `running` or `paused`.
  Future<Result<void>> deleteRun(String id) async {
    final runResult = await _runs.getById(id);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    final run = runResult.valueOrNull!;
    if (run.status.isActive) {
      return FailureResult(
        ConflictFailure(
          'Cannot delete active run "$id" with status "${run.status.name}".',
        ),
      );
    }

    return await _runs.delete(id);
  }
}
