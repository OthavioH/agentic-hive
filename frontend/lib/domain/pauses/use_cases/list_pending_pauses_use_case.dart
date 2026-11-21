import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists all currently pending pauses.
final class ListPendingPausesUseCase {
  /// Creates a [ListPendingPausesUseCase].
  const new(this._repository);

  final PauseRepository _repository;

  /// Fetches pending pauses ordered by `createdAt` ascending.
  Future<Result<List<Pause>>> call() => _repository.listPendingPauses();
}
