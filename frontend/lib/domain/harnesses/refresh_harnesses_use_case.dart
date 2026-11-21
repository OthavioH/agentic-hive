import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Re-runs detection for all supported CLI harnesses.
final class RefreshHarnessesUseCase {
  /// Creates a [RefreshHarnessesUseCase].
  const new(this._repository);

  final HarnessRepository _repository;

  /// Triggers a full harness refresh on the backend and returns updated items.
  Future<Result<List<HarnessInfo>>> call() => _repository.refreshAll();
}
