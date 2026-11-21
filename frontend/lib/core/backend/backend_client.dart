import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Transport interface for communicating with the local Agentic Hive backend.
abstract interface class BackendClient {
  /// Checks backend readiness and dependency health via `GET /api/v1/status`.
  Future<Result<StatusResponse>> checkStatus();

  /// Sends a `GET` request to [path] and decodes the JSON object response.
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout});

  /// Sends a `POST` request to [path] with an optional JSON [body] and decodes
  /// the JSON object response.
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  });

  /// Opens a WebSocket connection to `GET /ws` and completes the
  /// `server.hello` handshake.
  Future<Result<BackendWebSocketSession>> connectWebSocket();

  /// Closes underlying transport resources.
  Future<void> close();
}
