import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Starts a new workflow [Run] from a [StartRunRequest].
final class StartRun {
  /// Creates a [StartRun] use case backed by [_repository].
  const new(this._repository);

  final RunRepository _repository;

  /// Executes the use case with [request].
  Future<Result<Run>> call(StartRunRequest request) =>
      _repository.startRun(request);
}
