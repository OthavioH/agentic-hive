import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches all saved checkpoints for a run.
final class GetRunCheckpoints {
  /// Creates a [GetRunCheckpoints] use case backed by [_repository].
  const new(this._repository);

  final RunRepository _repository;

  /// Executes the use case for run [id].
  Future<Result<List<Checkpoint>>> call(String id) =>
      _repository.getRunCheckpoints(id);
}
