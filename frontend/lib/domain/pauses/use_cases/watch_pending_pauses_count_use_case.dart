import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';

/// Observes the live count of pending pauses for the navigation rail badge.
final class WatchPendingPausesCountUseCase {
  /// Creates a [WatchPendingPausesCountUseCase].
  const new(this._repository);

  final PauseRepository _repository;

  /// Streams the current pending pause count.
  Stream<int> call() => _repository.watchPendingPausesCount();
}
