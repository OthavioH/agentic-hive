import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Requests cancellation of an active or `cancellationUncertain` [Run].
final class CancelRun {
  /// Creates a [CancelRun] use case backed by [_repository].
  const new(this._repository);

  final RunRepository _repository;

  /// Executes the use case for run [id].
  Future<Result<Run>> call(String id) => _repository.cancelRun(id);
}
