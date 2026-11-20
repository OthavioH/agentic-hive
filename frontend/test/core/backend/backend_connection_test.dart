import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  Result<HealthResponse> nextHealth = const Success(HealthResponse());
  bool closed = false;

  @override
  Future<Result<HealthResponse>> checkHealth() async => nextHealth;

  @override
  Future<Result<WebSocket>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('Not used in unit test.'));

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  group('BackendConnection', () {
    test(
      'transitions from connecting to connected when health succeeds',
      () async {
        final fake = _FakeBackendClient();
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(fake)],
        );

        expect(
          container.read(backendConnectionProvider),
          BackendConnectionState.connecting,
        );

        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(backendConnectionProvider),
          BackendConnectionState.connected,
        );
      },
    );

    test(
      'transitions to disconnected on failure and recovers on reconnect',
      () async {
        final fake = _FakeBackendClient()
          ..nextHealth = const FailureResult(NetworkFailure('offline'));
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(fake)],
        );

        expect(
          container.read(backendConnectionProvider),
          BackendConnectionState.connecting,
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(backendConnectionProvider),
          BackendConnectionState.disconnected,
        );

        fake.nextHealth = const Success(HealthResponse());
        await container.read(backendConnectionProvider.notifier).reconnect();

        expect(
          container.read(backendConnectionProvider),
          BackendConnectionState.connected,
        );
      },
    );
  });
}
