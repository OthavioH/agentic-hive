import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';

/// Deletes a non-active run by ID.
final class DeleteRun {
  /// Creates a [DeleteRun] use case backed by [_repository].
  const new(this._repository);

  final RunRepository _repository;

  /// Executes the use case for run [id].
  Future<Result<void>> call(String id) => _repository.deleteRun(id);
}
