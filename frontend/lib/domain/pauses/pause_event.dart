import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Domain event emitted when a pause changes via WebSocket or reconnect sync.
sealed class PauseEvent {
  /// Creates a [PauseEvent].
  const new();
}

/// A new pause was created and is waiting for human input.
final class PauseCreatedEvent extends PauseEvent {
  /// Creates a [PauseCreatedEvent].
  const new(this.pause);

  /// The created pause.
  final Pause pause;
}

/// An existing pause was answered or cancelled.
final class PauseResolvedEvent extends PauseEvent {
  /// Creates a [PauseResolvedEvent].
  const new(this.pause);

  /// The resolved pause.
  final Pause pause;
}

/// The backend WebSocket connected or reconnected, so clients should sync.
final class PauseSyncRequestedEvent extends PauseEvent {
  /// Creates a [PauseSyncRequestedEvent].
  const new();
}
