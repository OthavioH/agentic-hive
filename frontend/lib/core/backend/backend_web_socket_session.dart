import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Machine-readable failure codes produced by `BackendClient` transport and
/// handshake checks.
abstract final class BackendFailureCode {
  /// `server.json` was not found in the platform data folder.
  static const String notRunning = 'not_running';

  /// The socket refused connections or was stale.
  static const String connectionRefused = 'connection_refused';

  /// The backend reported `degraded` (`503` or `BackendStatus.degraded`).
  static const String degraded = 'degraded';

  /// `server.hello` reported an incompatible WebSocket protocol version.
  static const String protocolMismatch = 'protocol_mismatch';

  /// A socket connect, HTTP status request, or WebSocket handshake timed out.
  static const String timeout = 'timeout';
}

/// Typed live WebSocket session with the local Agentic Hive backend.
///
/// Created only after receiving and validating the initial `server.hello`
/// handshake frame.
abstract interface class BackendWebSocketSession {
  /// Validated handshake payload received from the backend on connect.
  ServerHelloPayload get serverHello;

  /// Broadcast stream of post-handshake [WsEnvelope] messages from the backend.
  Stream<WsEnvelope> get messages;

  /// Completes when the underlying WebSocket connection closes.
  Future<void> get done;

  /// Whether this session has closed.
  bool get isClosed;

  /// Encodes and sends a [WsEnvelope] to the backend.
  Future<Result<void>> send(WsEnvelope envelope);

  /// Closes the WebSocket session.
  Future<void> close([int? code, String? reason]);
}
