import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<Result<StatusResponse>> checkStatus() async => nextStatus;

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async {
    final handler = onConnectWebSocket;
    if (handler != null) return handler();
    return Success(_FakeWebSocketSession());
  }

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
  });
}
