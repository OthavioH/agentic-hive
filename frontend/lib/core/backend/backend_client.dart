import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Transport interface for communicating with the local Agentic Hive backend.
abstract interface class BackendClient {
  /// Checks backend readiness and dependency health via `GET /api/v1/status`.
  Future<Result<StatusResponse>> checkStatus();

  /// Opens a WebSocket connection to `GET /ws` and completes the
  /// `server.hello` handshake.
  Future<Result<BackendWebSocketSession>> connectWebSocket();

  /// Sends a `GET` request to [path] and decodes the JSON object response.
  Future<Result<JsonMap>> getJson(String path);

  /// Sends a `POST` request to [path] with JSON [body] and decodes the JSON
  /// object response.
  Future<Result<JsonMap>> postJson(String path, JsonMap body);

  /// Sends a `PUT` request to [path] with JSON [body] and decodes the JSON
  /// object response.
  Future<Result<JsonMap>> putJson(String path, JsonMap body);

  /// Sends a `DELETE` request to [path].
  Future<Result<void>> delete(String path);

  /// Closes underlying transport resources.
  Future<void> close();
}
