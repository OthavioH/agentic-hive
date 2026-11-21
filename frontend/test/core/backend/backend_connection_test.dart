import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeTimer implements Timer {
  new(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _active = false;
  }

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}

final class _FakeWebSocketSession implements BackendWebSocketSession {
  final StreamController<WsEnvelope> _messages =
      StreamController<WsEnvelope>.broadcast();
  final Completer<void> _done = Completer<void>();
  bool _closed = false;

  @override
  ServerHelloPayload get serverHello => const ServerHelloPayload(
    serverVersion: '0.1.0',
    protocolVersion: wsProtocolVersion,
  );

  @override
  Stream<WsEnvelope> get messages => _messages.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => _closed;

  final List<WsEnvelope> sent = <WsEnvelope>[];

  @override
  Future<Result<void>> send(WsEnvelope envelope) async {
    if (_closed) {
      return const FailureResult(NetworkFailure('Session closed'));
    }
    sent.add(envelope);
    return const Success(null);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    drop();
  }

  void drop() {
    if (_closed) return;
    _closed = true;
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
    if (!_done.isCompleted) {
      _done.complete();
    }
  }
}

final class _FakeBackendClient implements BackendClient {
  Future<Result<StatusResponse>> Function()? onCheckStatus;
  Result<StatusResponse> nextStatus = const Success(
    StatusResponse(
      status: BackendStatus.ok,
      version: '0.1.0',
      uptimeSeconds: 10,
      dataDir: '/tmp/hive',
      database: DatabaseStatus(ok: true, schemaVersion: 1),
    ),
  );
  Result<BackendWebSocketSession> Function()? onConnectWebSocket;
  bool closed = false;

  @override
  Future<Result<StatusResponse>> checkStatus() {
    final handler = onCheckStatus;
    if (handler != null) return handler();
    return Future.value(nextStatus);
  }

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async {
    final handler = onConnectWebSocket;
    if (handler != null) return handler();
    return Success(_FakeWebSocketSession());
  }

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async => const Success(<String, Object?>{});

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  group('BackendConnection', () {
    test(
      'transitions from connecting to connected when status and ws succeed',
      () async {
        final fake = _FakeBackendClient();
        final container = ProviderContainer.test(
          overrides: [
            backendClientProvider.overrideWithValue(fake),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(nextRandomDouble: () => 0.5),
            ),
          ],
        );

        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnecting>(),
        );

        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnected>(),
        );
      },
    );

    test(
      'transitions to disconnected on failure and recovers on reconnect',
      () async {
        final fake = _FakeBackendClient()
          ..nextStatus = const FailureResult(
            NetworkFailure('offline', code: BackendFailureCode.notRunning),
          );
        final container = ProviderContainer.test(
          overrides: [
            backendClientProvider.overrideWithValue(fake),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(nextRandomDouble: () => 0.5),
            ),
          ],
        );

        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnecting>(),
        );
        await Future<void>.delayed(Duration.zero);

        final disconnected = container.read(backendConnectionProvider);
        expect(disconnected, isA<BackendDisconnected>());
        expect(
          (disconnected as BackendDisconnected).reason,
          ConnectionFailureReason.notRunning,
        );
        const expectedDelaySeconds = 1;
        expect(
          disconnected.nextRetryDelay,
          const Duration(seconds: expectedDelaySeconds),
        );

        fake.nextStatus = const Success(
          StatusResponse(
            status: BackendStatus.ok,
            version: '0.1.0',
            uptimeSeconds: 1,
            dataDir: '/tmp/hive',
            database: DatabaseStatus(ok: true, schemaVersion: 1),
          ),
        );
        await container.read(backendConnectionProvider.notifier).reconnect();

        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnected>(),
        );
      },
    );

    test('halts automatic retries on protocolMismatch', () async {
      final fake = _FakeBackendClient()
        ..onConnectWebSocket = () => const FailureResult(
          BackendFailure(
            'Version mismatch',
            code: BackendFailureCode.protocolMismatch,
          ),
        );
      final container = ProviderContainer.test(
        overrides: [
          backendClientProvider.overrideWithValue(fake),
          backendConnectionConfigProvider.overrideWithValue(
            BackendConnectionConfig(nextRandomDouble: () => 0.5),
          ),
        ],
      );

      expect(
        container.read(backendConnectionProvider),
        isA<BackendConnecting>(),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(backendConnectionProvider);
      expect(state, isA<BackendDisconnected>());
      final disconnected = state as BackendDisconnected;
      expect(disconnected.reason, ConnectionFailureReason.protocolMismatch);
      expect(disconnected.isAutoRetryHalted, isTrue);
      expect(disconnected.nextRetryDelay, isNull);
    });

    test(
      '2-second grace period absorbs quick WebSocket recovery silently',
      () async {
        final firstSession = _FakeWebSocketSession();
        final secondSession = _FakeWebSocketSession();
        var connectCalls = 0;
        final fake = _FakeBackendClient()
          ..onConnectWebSocket = () {
            connectCalls++;
            return Success(connectCalls == 1 ? firstSession : secondSession);
          };

        final container = ProviderContainer.test(
          overrides: [
            backendClientProvider.overrideWithValue(fake),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(nextRandomDouble: () => 0.5),
            ),
          ],
        );

        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnecting>(),
        );
        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnecting>(),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(backendConnectionProvider).sessionOrNull,
          same(firstSession),
        );

        // Drop the first session; immediate silent reconnect succeeds.
        firstSession.drop();
        await Future<void>.delayed(Duration.zero);

        final state = container.read(backendConnectionProvider);
        expect(state, isA<BackendConnected>());
        expect((state as BackendConnected).isReconnectingSilently, isFalse);
        expect(state.session, same(secondSession));
      },
    );

    test(
      'progresses exponential backoff 1s -> 2s -> 4s -> 8s -> 10s cap',
      () async {
        final scheduledTimers = <_FakeTimer>[];
        var currentNow = DateTime.utc(2026, 11, 20, 12);
        final fake = _FakeBackendClient()
          ..nextStatus = const FailureResult(
            NetworkFailure('offline', code: BackendFailureCode.notRunning),
          );

        final container = ProviderContainer.test(
          overrides: [
            backendClientProvider.overrideWithValue(fake),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(
                now: () => currentNow,
                nextRandomDouble: () => 0.5,
                createTimer: (duration, callback) {
                  final timer = _FakeTimer(duration, callback);
                  scheduledTimers.add(timer);
                  return timer;
                },
              ),
            ),
          ],
        );

        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnecting>(),
        );
        await Future<void>.delayed(Duration.zero);

        const expectedSeconds = <int>[1, 2, 4, 8, 10, 10];
        for (var i = 0; i < expectedSeconds.length; i++) {
          final expectedDelay = Duration(seconds: expectedSeconds[i]);
          final state =
              container.read(backendConnectionProvider) as BackendDisconnected;
          expect(state.attempt, i + 1);
          expect(state.nextRetryDelay, expectedDelay);
          expect(state.nextRetryAt, currentNow.add(expectedDelay));

          if (i < expectedSeconds.length - 1) {
            currentNow = currentNow.add(expectedDelay);
            scheduledTimers.last.fire();
            await Future<void>.delayed(Duration.zero);
          }
        }
      },
    );

    test(
      'manual reconnect() after multiple failures resets backoff to 1s',
      () async {
        final scheduledTimers = <_FakeTimer>[];
        final fake = _FakeBackendClient()
          ..nextStatus = const FailureResult(
            NetworkFailure('offline', code: BackendFailureCode.notRunning),
          );

        final container = ProviderContainer.test(
          overrides: [
            backendClientProvider.overrideWithValue(fake),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(
                now: () => DateTime.utc(2026, 11, 20, 12),
                nextRandomDouble: () => 0.5,
                createTimer: (duration, callback) {
                  final timer = _FakeTimer(duration, callback);
                  scheduledTimers.add(timer);
                  return timer;
                },
              ),
            ),
          ],
        );

        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnecting>(),
        );
        await Future<void>.delayed(Duration.zero);
        // Advance through 1s and 2s failures so attempt 3 schedules 4s.
        scheduledTimers.last.fire();
        await Future<void>.delayed(Duration.zero);
        scheduledTimers.last.fire();
        await Future<void>.delayed(Duration.zero);

        const beforeDelaySeconds = 4;
        const afterDelaySeconds = 1;
        final beforeManual =
            container.read(backendConnectionProvider) as BackendDisconnected;
        expect(beforeManual.attempt, 3);
        expect(
          beforeManual.nextRetryDelay,
          const Duration(seconds: beforeDelaySeconds),
        );

        // Trigger manual reconnect while backend is still failing.
        await container.read(backendConnectionProvider.notifier).reconnect();

        final afterManual =
            container.read(backendConnectionProvider) as BackendDisconnected;
        expect(afterManual.attempt, 1);
        expect(
          afterManual.nextRetryDelay,
          const Duration(seconds: afterDelaySeconds),
        );
      },
    );

    test(
      'grace period expiration supersedes in-flight silent reconnect attempt',
      () async {
        final scheduledTimers = <_FakeTimer>[];
        final firstSession = _FakeWebSocketSession();
        final staleSession = _FakeWebSocketSession();
        final statusCompleter = Completer<Result<StatusResponse>>();
        var statusCalls = 0;

        final fake = _FakeBackendClient()
          ..onCheckStatus = () {
            statusCalls++;
            if (statusCalls == 1) {
              return Future.value(
                const Success(
                  StatusResponse(
                    status: BackendStatus.ok,
                    version: '0.1.0',
                    uptimeSeconds: 10,
                    dataDir: '/tmp/hive',
                    database: DatabaseStatus(ok: true, schemaVersion: 1),
                  ),
                ),
              );
            }
            return statusCompleter.future;
          }
          ..onConnectWebSocket = () =>
              Success(statusCalls == 1 ? firstSession : staleSession);

        final container = ProviderContainer.test(
          overrides: [
            backendClientProvider.overrideWithValue(fake),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(
                now: () => DateTime.utc(2026, 11, 20, 12),
                nextRandomDouble: () => 0.5,
                createTimer: (duration, callback) {
                  final timer = _FakeTimer(duration, callback);
                  scheduledTimers.add(timer);
                  return timer;
                },
              ),
            ),
          ],
        );

        expect(
          container.read(backendConnectionProvider),
          isA<BackendConnecting>(),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(backendConnectionProvider).sessionOrNull,
          same(firstSession),
        );

        // Drop first session; silent reconnect hangs on checkStatus().
        firstSession.drop();
        await Future<void>.delayed(Duration.zero);
        expect(
          (container.read(
            backendConnectionProvider,
          ) as BackendConnected).isReconnectingSilently,
          isTrue,
        );
        expect(scheduledTimers, hasLength(1));
        expect(
          scheduledTimers.single.duration,
          BackendConnectionConfig.defaultGracePeriod,
        );

        // Grace period expires while silent attempt is still in-flight.
        scheduledTimers.single.fire();

        final disconnected = container.read(backendConnectionProvider);
        expect(disconnected, isA<BackendDisconnected>());
        expect(
          (disconnected as BackendDisconnected).reason,
          ConnectionFailureReason.timeout,
        );
        const expectedDelaySeconds = 1;
        expect(
          disconnected.nextRetryDelay,
          const Duration(seconds: expectedDelaySeconds),
        );

        // Stale silent attempt now resolves; it must be ignored.
        statusCompleter.complete(
          const Success(
            StatusResponse(
              status: BackendStatus.ok,
              version: '0.1.0',
              uptimeSeconds: 12,
              dataDir: '/tmp/hive',
              database: DatabaseStatus(ok: true, schemaVersion: 1),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(backendConnectionProvider),
          isA<BackendDisconnected>(),
        );
        expect(staleSession.isClosed, isFalse);
      },
    );
  });
}
