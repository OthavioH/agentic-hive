import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches captured `stdout`/`stderr` logs for a node attempt in a run.
final class GetNodeLogs {
  /// Creates a [GetNodeLogs] use case backed by [_repository].
  const new(this._repository);

  final RunRepository _repository;

  /// Executes the use case for [nodeId] in run [runId].
  Future<Result<RunNodeLogsResponse>> call(
    String runId,
    String nodeId, {
    int? attempt,
    int? tail,
  }) => _repository.getNodeLogs(runId, nodeId, attempt: attempt, tail: tail);
}
