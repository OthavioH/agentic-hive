import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches the current [OverviewSnapshot] from the backend.
final class GetOverviewUseCase {
  /// Creates a [GetOverviewUseCase].
  const new(this._repository);

  final OverviewRepository _repository;

  /// Loads the latest [OverviewSnapshot].
  Future<Result<OverviewSnapshot>> call() => _repository.getOverview();
}
