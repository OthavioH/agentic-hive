import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';

/// Categorized reason why the frontend could not connect to the backend.
enum ConnectionFailureReason {
  /// `server.json` is missing — the backend is not running.
  notRunning,

  /// `server.json` exists, but the socket refused connections or is stale.
  connectionRefused,

  /// `GET /api/v1/status` reported `503` / `BackendStatus.degraded`.
  degraded,

  /// `server.hello` reported an incompatible WebSocket protocol version.
  protocolMismatch,

  /// Connecting, checking status, or awaiting `server.hello` timed out.
  timeout,

  /// An unexpected transport or payload error occurred.
  unexpected,
}

/// Connection state of the local Agentic Hive backend.
@immutable
sealed class BackendConnectionState {
  const new();

  /// Whether the app currently holds a live connection (including during the
  /// 2-second silent grace period after a WebSocket drop).
  bool get isConnected => this is BackendConnected;

  /// Whether an explicit connection attempt is in progress.
  bool get isConnecting => this is BackendConnecting;

  /// Whether the app is disconnected and waiting to retry (or halted).
  bool get isDisconnected => this is BackendDisconnected;

  /// The active WebSocket session when connected, or `null` otherwise.
  BackendWebSocketSession? get sessionOrNull => switch (this) {
    BackendConnected(:final session) => session,
    _ => null,
  };
}

/// Initial or manual connection attempt is in progress.
final class BackendConnecting extends BackendConnectionState {
  /// Creates a connecting state.
  const new({this.isRetry = false});

  /// Whether this attempt is a retry after a prior failure or grace timeout.
  final bool isRetry;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackendConnecting && other.isRetry == isRetry;

  @override
  int get hashCode => isRetry.hashCode;
}

/// Backend status and `server.hello` handshake succeeded.
final class BackendConnected extends BackendConnectionState {
  /// Creates a connected state.
  const new({
    required this.session,
    required this.status,
    this.isReconnectingSilently = false,
  });

  /// Active typed WebSocket session.
  final BackendWebSocketSession session;

  /// Latest `GET /api/v1/status` response.
  final StatusResponse status;

  /// `true` during the 2-second silent grace period after a WebSocket drop.
  final bool isReconnectingSilently;

  /// Returns a copy with updated fields.
  BackendConnected copyWith({
    BackendWebSocketSession? session,
    StatusResponse? status,
    bool? isReconnectingSilently,
  }) => BackendConnected(
    session: session ?? this.session,
    status: status ?? this.status,
    isReconnectingSilently:
        isReconnectingSilently ?? this.isReconnectingSilently,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackendConnected &&
          identical(other.session, session) &&
          other.status == status &&
          other.isReconnectingSilently == isReconnectingSilently;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(session), status, isReconnectingSilently);
}

/// Backend is unreachable, degraded, or incompatible.
final class BackendDisconnected extends BackendConnectionState {
  /// Creates a disconnected state.
  const new({
    required this.reason,
    required this.attempt,
    this.detail,
    this.nextRetryDelay,
    this.nextRetryAt,
  });

  /// Categorized failure reason.
  final ConnectionFailureReason reason;

  /// 1-indexed count of consecutive failed attempts.
  final int attempt;

  /// Optional diagnostic detail (never contains secrets).
  final String? detail;

  /// Delay until the next automatic retry, or `null` when auto-retry halted.
  final Duration? nextRetryDelay;

  /// Timestamp of the next automatic retry, or `null` when auto-retry halted.
  final DateTime? nextRetryAt;

  /// Whether automatic retries have been halted (e.g. protocol mismatch).
  bool get isAutoRetryHalted => nextRetryDelay == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackendDisconnected &&
          other.reason == reason &&
          other.attempt == attempt &&
          other.detail == detail &&
          other.nextRetryDelay == nextRetryDelay &&
          other.nextRetryAt == nextRetryAt;

  @override
  int get hashCode =>
      Object.hash(reason, attempt, detail, nextRetryDelay, nextRetryAt);
}
