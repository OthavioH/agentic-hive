import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Live WebSocket and reconnect events relevant to the Overview dashboard.
sealed class OverviewEvent {
  /// Creates an [OverviewEvent].
  const new();
}

/// Emitted when a `run.event` WebSocket message arrives (`run.*` or `node.*`).
final class OverviewRunEventReceived extends OverviewEvent {
  /// Creates an [OverviewRunEventReceived].
  const new(this.event);

  /// The received run or node lifecycle event.
  final RunEvent event;
}

/// Emitted when a `pause.created` WebSocket message arrives.
final class OverviewPauseCreatedEvent extends OverviewEvent {
  /// Creates an [OverviewPauseCreatedEvent].
  const new(this.pause);

  /// The newly created pending pause.
  final Pause pause;
}

/// Emitted when a `pause.resolved` WebSocket message arrives.
final class OverviewPauseResolvedEvent extends OverviewEvent {
  /// Creates an [OverviewPauseResolvedEvent].
  const new(this.pause);

  /// The resolved or cancelled pause.
  final Pause pause;
}

/// Emitted when the WebSocket reconnects and a full snapshot resync is
/// required.
final class OverviewSyncRequestedEvent extends OverviewEvent {
  /// Creates an [OverviewSyncRequestedEvent].
  const new();
}
