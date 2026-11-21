import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Re-runs detection for a single CLI harness.
final class RefreshHarnessUseCase {
  /// Creates a [RefreshHarnessUseCase].
  const new(this._repository);

  final HarnessRepository _repository;

  /// Triggers detection for [id] on the backend and returns its updated state.
  Future<Result<HarnessInfo>> call(HarnessId id) =>
      _repository.refreshHarness(id);
}
