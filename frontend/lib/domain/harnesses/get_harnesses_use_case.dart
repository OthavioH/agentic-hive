import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches the current list of detected CLI harnesses.
final class GetHarnessesUseCase {
  /// Creates a [GetHarnessesUseCase].
  const new(this._repository);

  final HarnessRepository _repository;

  /// Returns all detected harnesses from the backend.
  Future<Result<List<HarnessInfo>>> call() => _repository.getHarnesses();
}
