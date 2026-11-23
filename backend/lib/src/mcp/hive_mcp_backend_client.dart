import 'package:agentic_hive_backend/src/mcp/hive_mcp_socket_client.dart';

export 'package:agentic_hive_backend/src/mcp/hive_mcp_socket_client.dart'
    show BackendToolCallResponse;

/// Stateless Unix-domain-socket HTTP client used by `hive-mcp` (ADR 0011,
/// ADR 0015).
///
/// Never opens TCP ports, never sends an `Origin` header, holds no state, and
/// performs no retry loops.
final class HiveMcpBackendClient {
  /// Creates a client targeting [socketPath] for a single node attempt.
  new({
    required this.socketPath,
    required this.runId,
    required this.nodeId,
    required this.attempt,
  });

  /// Path to the backend Unix domain socket.
  final String socketPath;

  /// Active run identifier.
  final String runId;

  /// Active node identifier.
  final String nodeId;

  /// 1-based node attempt number.
  final int attempt;

  HiveMcpSocketClient get _socket =>
      HiveMcpSocketClient(socketPath: socketPath);

  String get _basePath =>
      '/api/v1/internal/runs/${Uri.encodeComponent(runId)}'
      '/nodes/${Uri.encodeComponent(nodeId)}'
      '/attempts/$attempt';

  /// Forwards `report_result` to the backend.
  Future<BackendToolCallResponse> reportResult(
    Map<String, Object?> arguments,
  ) => _socket.postJson(
    '$_basePath/report-result',
    arguments,
    timeout: const Duration(seconds: 15),
  );

  /// Forwards `ask_human` to the backend with no short HTTP timeout so it
  /// blocks cleanly until the human answers or the run is cancelled.
  Future<BackendToolCallResponse> askHuman(Map<String, Object?> arguments) =>
      _socket.postJson('$_basePath/ask-human', arguments);
}
