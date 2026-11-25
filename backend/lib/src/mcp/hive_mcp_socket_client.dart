import 'dart:convert';
import 'dart:io';

/// Response from forwarding an MCP tool call to the backend over the Unix
/// domain socket.
final class BackendToolCallResponse {
  /// Creates a response.
  const new({
    required this.isError,
    required this.message,
    this.backendUnreachable = false,
  });

  /// Whether the backend rejected the call or transport failed.
  final bool isError;

  /// Human/agent-readable response text or diagnostic error message.
  final String message;

  /// Whether the socket could not be connected (the backend is not running).
  final bool backendUnreachable;
}

/// One Unix-domain-socket HTTP client for the local backend (ADR 0011).
final class HiveMcpSocketClient {
  /// Creates a client targeting [socketPath].
  const new({required this.socketPath});

  /// Path to the backend Unix domain socket.
  final String socketPath;

  /// POSTs [payload] as JSON to [path]; a null [timeout] waits indefinitely.
  Future<BackendToolCallResponse> postJson(
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
        backendUnreachable: error is SocketException,
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
