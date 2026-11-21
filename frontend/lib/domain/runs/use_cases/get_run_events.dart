import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches chronological events for a run.
final class GetRunEvents {
  /// Creates a [GetRunEvents] use case backed by [_repository].
  const new(this._repository);

  final RunRepository _repository;

  /// Executes the use case for run [id].
  Future<Result<RunEventsResponse>> call(
    String id, {
    int? afterSequence,
    int? limit,
  }) =>
      _repository.getRunEvents(id, afterSequence: afterSequence, limit: limit);
}
