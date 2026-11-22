import 'package:agentic_hive_frontend/domain/overview/overview_event.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_repository.dart';

/// Observes live [OverviewEvent]s from the backend WebSocket.
final class WatchOverviewEventsUseCase {
  /// Creates a [WatchOverviewEventsUseCase].
  const new(this._repository);

  final OverviewRepository _repository;

  /// Streams [OverviewEvent] updates.
  Stream<OverviewEvent> call() => _repository.watchOverviewEvents();
}
