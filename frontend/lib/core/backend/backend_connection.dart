import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backend_connection.g.dart';

/// Connectivity status of the local backend service.
enum BackendConnectionState {
  /// Initial or retry connection check is in progress.
  connecting,

  /// Backend answered `/health` successfully.
  connected,

  /// Backend is unreachable or returned an error.
  disconnected,
}

/// Tracks connectivity to the local backend and supports reconnection.
@Riverpod(keepAlive: true)
class BackendConnection extends _$BackendConnection {
  /// Initializes the connection state and triggers the initial health check.
  @override
  BackendConnectionState build() {
    unawaited(Future.microtask(checkConnection));
    return BackendConnectionState.connecting;
  }

  /// Checks `/health` against the current `backendClientProvider` and updates
  /// the connection state.
  Future<void> checkConnection() async {
    state = BackendConnectionState.connecting;
    final client = ref.read(backendClientProvider);
    final result = await client.checkHealth();
    if (!ref.mounted) return;
    state = result.isSuccess
        ? BackendConnectionState.connected
        : BackendConnectionState.disconnected;
  }

  /// Triggers a reconnection attempt.
  Future<void> reconnect() => checkConnection();
}
