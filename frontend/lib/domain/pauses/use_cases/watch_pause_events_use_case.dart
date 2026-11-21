import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';

/// Observes live pause creation, resolution, and reconnect-sync events.
final class WatchPauseEventsUseCase {
  /// Creates a [WatchPauseEventsUseCase].
  const new(this._repository);

  final PauseRepository _repository;

  /// Streams [PauseEvent] updates from the repository.
  Stream<PauseEvent> call() => _repository.watchPauseEvents();
}
