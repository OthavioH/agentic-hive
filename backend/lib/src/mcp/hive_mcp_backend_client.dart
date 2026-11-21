import 'dart:convert';
import 'dart:io';

/// Response from forwarding an MCP tool call to the backend over the Unix
/// domain socket.
final class BackendToolCallResponse {
  /// Creates a response.
  const new({required this.isError, required this.message});

  /// Whether the backend rejected the call or transport failed.
  final bool isError;

  /// Human/agent-readable response text or diagnostic error message.
  final String message;
}

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

  String get _basePath =>
      '/api/v1/internal/runs/${Uri.encodeComponent(runId)}'
      '/nodes/${Uri.encodeComponent(nodeId)}'
      '/attempts/$attempt';

  /// Forwards `report_result` to the backend.
  Future<BackendToolCallResponse> reportResult(
    Map<String, Object?> arguments,
  ) => _postJson(
    '$_basePath/report-result',
    arguments,
    timeout: const Duration(seconds: 15),
  );

  /// Forwards `ask_human` to the backend with no short HTTP timeout so it
  /// blocks cleanly until the human answers or the run is cancelled.
  Future<BackendToolCallResponse> askHuman(Map<String, Object?> arguments) =>
      _postJson('$_basePath/ask-human', arguments);

  Future<BackendToolCallResponse> _postJson(
    String path,
    Map<String, Object?> payload, {
    Duration? timeout,
  }) async {
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    final client = HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) =>
          Socket.startConnect(address, 0);
    if (timeout == null) {
      // Allow long-lived ask_human calls to stay open without idle timeouts.
      client.idleTimeout = const Duration(days: 365);
    }

    try {
      final uri = Uri.parse('http://localhost$path');
      final openFuture = client.postUrl(uri);
      final request = timeout != null
          ? await openFuture.timeout(timeout)
          : await openFuture;
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final responseFuture = request.close();
      final response = timeout != null
          ? await responseFuture.timeout(timeout)
          : await responseFuture;

      final bodyFuture = response.transform(utf8.decoder).join();
      final body = timeout != null
          ? await bodyFuture.timeout(timeout)
          : await bodyFuture;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BackendToolCallResponse(isError: false, message: body);
      }

      return BackendToolCallResponse(
        isError: true,
        message: _extractErrorMessage(response.statusCode, body),
      );
    } on Object catch (error) {
      return BackendToolCallResponse(
        isError: true,
        message:
            'Failed to reach Agentic Hive backend at "$socketPath": $error',
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _extractErrorMessage(int statusCode, String body) {
    if (body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, Object?>) {
          final errorObj = decoded['error'];
          if (errorObj is Map<String, Object?> &&
              errorObj['message'] is String &&
              (errorObj['message']! as String).trim().isNotEmpty) {
            return errorObj['message']! as String;
          }
          final message = decoded['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message;
          }
        }
      } on FormatException {
        // Fall through to status code + raw body.
      }
      return 'Backend returned HTTP $statusCode: $body';
    }
    return 'Backend returned HTTP $statusCode.';
  }
}
