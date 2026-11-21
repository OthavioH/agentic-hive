import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection_config.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection_state.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'backend_connection_config.dart';
export 'backend_connection_state.dart';

part 'backend_connection.g.dart';

/// Tracks connectivity to the local backend, manages the live WebSocket
/// session, and drives automatic reconnection with exponential backoff and a
/// 2-second silent grace period on drop.
@Riverpod(keepAlive: true)
class BackendConnection extends _$BackendConnection {
  static const int _baseBackoffMs = 1000;
  static const int _minJitteredMs = 500;
  static const double _jitterFraction = 0.1;

  Timer? _retryTimer;
  Timer? _graceTimer;
  BackendWebSocketSession? _activeSession;
  int _attempt = 0;
  int _generation = 0;
  bool _disposed = false;

  @override
  BackendConnectionState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _retryTimer?.cancel();
      _retryTimer = null;
      _graceTimer?.cancel();
      _graceTimer = null;
      final session = _activeSession;
      _activeSession = null;
      if (session != null) {
        unawaited(session.close());
      }
    });

    unawaited(Future.microtask(connect));
    return const BackendConnecting();
  }

  /// Starts an immediate connection attempt, resetting backoff.
  Future<void> connect() => _startImmediateAttempt(isRetry: false);

  /// Manually triggers an immediate reconnection attempt and resets backoff.
  Future<void> reconnect() => _startImmediateAttempt(isRetry: true);

  /// Sends [envelope] over the active WebSocket session, or returns a
  /// [FailureResult] when disconnected.
  Future<Result<void>> send(WsEnvelope envelope) {
    final session = _activeSession;
    if (session == null || session.isClosed) {
      return Future.value(
        const FailureResult(
          NetworkFailure('Backend WebSocket is not connected.'),
        ),
      );
    }
    return session.send(envelope);
  }

  Future<void> _startImmediateAttempt({required bool isRetry}) async {
    if (_disposed || !ref.mounted) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _attempt = 0;
    _generation++;

    final previousSession = _activeSession;
    _activeSession = null;
    if (previousSession != null) {
      unawaited(previousSession.close());
    }

    state = BackendConnecting(isRetry: isRetry);
    await _attemptConnect(generation: _generation);
  }

  Future<void> _attemptConnect({required int generation}) async {
    final client = ref.read(backendClientProvider);

    final statusResult = await client.checkStatus();
    if (_disposed || !ref.mounted || generation != _generation) return;

    if (statusResult case FailureResult<StatusResponse>(:final failure)) {
      _handleFailure(failure);
      return;
    }
    final status = (statusResult as Success<StatusResponse>).value;

    final wsResult = await client.connectWebSocket();
    if (_disposed || !ref.mounted || generation != _generation) {
      if (wsResult case Success<BackendWebSocketSession>(:final value)) {
        unawaited(value.close());
      }
      return;
    }

    if (wsResult case FailureResult<BackendWebSocketSession>(:final failure)) {
      _handleFailure(failure);
      return;
    }
    final session = (wsResult as Success<BackendWebSocketSession>).value;

    _graceTimer?.cancel();
    _graceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _attempt = 0;
    _activeSession = session;

    state = BackendConnected(session: session, status: status);
    unawaited(session.done.then((_) => _onSessionClosed(session)));
  }

  void _onSessionClosed(BackendWebSocketSession closedSession) {
    if (_disposed || !ref.mounted) return;
    if (!identical(_activeSession, closedSession)) return;
    _activeSession = null;

    final current = state;
    if (current is! BackendConnected) return;

    final config = ref.read(backendConnectionConfigProvider);
    state = current.copyWith(isReconnectingSilently: true);

    _graceTimer?.cancel();
    _graceTimer = config.createTimer(config.gracePeriod, _onGracePeriodExpired);

    _generation++;
    unawaited(_attemptConnect(generation: _generation));
  }

  void _onGracePeriodExpired() {
    if (_disposed || !ref.mounted) return;
    _graceTimer = null;
    if (state is BackendConnected) {
      // Supersede any in-flight silent attempt before transitioning out of the
      // grace period so it cannot race with the scheduled backoff cycle.
      _generation++;
      _handleFailure(
        const NetworkFailure(
          'Backend reconnection timed out.',
          code: BackendFailureCode.timeout,
        ),
      );
    }
  }

  void _handleFailure(Failure failure) {
    _graceTimer?.cancel();
    _graceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;

    final reason = _mapFailureToReason(failure);
    _attempt++;

    if (reason == ConnectionFailureReason.protocolMismatch) {
      state = BackendDisconnected(
        reason: reason,
        attempt: _attempt,
        detail: failure.message,
      );
      return;
    }

    final config = ref.read(backendConnectionConfigProvider);
    final delay = _computeBackoffDelay(_attempt, config);
    final nextRetryAt = config.now().add(delay);

    state = BackendDisconnected(
      reason: reason,
      attempt: _attempt,
      detail: failure.message,
      nextRetryDelay: delay,
      nextRetryAt: nextRetryAt,
    );

    final scheduledGeneration = _generation;
    _retryTimer = config.createTimer(delay, () {
      if (_disposed || !ref.mounted) return;
      if (scheduledGeneration != _generation) return;
      _retryTimer = null;
      state = const BackendConnecting(isRetry: true);
      unawaited(_attemptConnect(generation: scheduledGeneration));
    });
  }

  Duration _computeBackoffDelay(int attempt, BackendConnectionConfig config) {
    final maxMs = config.maxBackoff.inMilliseconds;
    final shift = min(attempt - 1, 10);
    final baseMs = min(_baseBackoffMs * (1 << shift), maxMs);
    final jitterFactor =
        1.0 + ((config.sampleRandomDouble() * 2.0 - 1.0) * _jitterFraction);
    final jitteredMs = (baseMs * jitterFactor).round().clamp(
      _minJitteredMs,
      maxMs,
    );
    return Duration(milliseconds: jitteredMs);
  }

  ConnectionFailureReason _mapFailureToReason(Failure failure) =>
      switch (failure) {
        NetworkFailure(:final code, :final cause) => switch (code) {
          BackendFailureCode.notRunning => ConnectionFailureReason.notRunning,
          BackendFailureCode.connectionRefused =>
            ConnectionFailureReason.connectionRefused,
          BackendFailureCode.timeout => ConnectionFailureReason.timeout,
          _ when cause is SocketException =>
            ConnectionFailureReason.connectionRefused,
          _ when cause is TimeoutException => ConnectionFailureReason.timeout,
          _ => ConnectionFailureReason.unexpected,
        },
        BackendFailure(:final code, :final statusCode) => switch (code) {
          BackendFailureCode.protocolMismatch =>
            ConnectionFailureReason.protocolMismatch,
          BackendFailureCode.degraded => ConnectionFailureReason.degraded,
          _ when statusCode == HttpStatus.serviceUnavailable =>
            ConnectionFailureReason.degraded,
          _ => ConnectionFailureReason.unexpected,
        },
        NotFoundFailure() ||
        ValidationFailure() ||
        UnexpectedFailure() => ConnectionFailureReason.unexpected,
      };
}

/// Exposes the active [BackendWebSocketSession] when connected, or `null`.
@riverpod
BackendWebSocketSession? backendWebSocketSession(Ref ref) =>
    ref.watch(backendConnectionProvider).sessionOrNull;

/// Broadcast stream of post-handshake [WsEnvelope] messages from the backend.
@riverpod
Stream<WsEnvelope> backendWsMessages(Ref ref) {
  final session = ref.watch(backendWebSocketSessionProvider);
  if (session == null) {
    return const Stream<WsEnvelope>.empty();
  }
  return session.messages;
}
