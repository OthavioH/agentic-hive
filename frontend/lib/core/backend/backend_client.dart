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

  /// Requests graceful backend shutdown via `POST /api/v1/shutdown`.
  Future<Result<ShutdownResponse>> shutdown({required bool force});

  /// Closes underlying transport resources.
  Future<void> close();
}
