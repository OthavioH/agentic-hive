import 'dart:convert';

import 'package:agentic_hive_backend/src/mcp/hive_mcp_socket_client.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Forwards backend-served tools (ADR 0026); the proxy stays stateless.
abstract interface class HiveMcpToolForwarder {
  /// Calls the backend tool [name] with [arguments].
  Future<BackendToolCallResponse> callTool(
    String name,
    Map<String, Object?> arguments,
  );
}

/// [HiveMcpToolForwarder] that posts to the backend's internal tools route.
final class HiveMcpToolsClient implements HiveMcpToolForwarder {
  /// Creates a client; a null [_socket] means socket discovery failed.
  const new({required this._socket, required this._cwd});

  /// Text answered when the backend cannot be reached.
  static const notRunningMessage =
      'Agentic Hive is not running. Start the Agentic Hive app, then call '
      'again.';

  /// Forward timeout of tools without a longer entry.
  static const defaultTimeout = Duration(seconds: 15);

  /// Longer timeouts: delete_workflow waits up to 20 s for its operation.
  static const _longTimeouts = <String, Duration>{
    'delete_workflow': Duration(seconds: 30),
  };

  /// Timeout used when forwarding the tool [name].
  static Duration timeoutFor(String name) =>
      _longTimeouts[name] ?? defaultTimeout;

  final HiveMcpSocketClient? _socket;
  final String _cwd;

  @override
  Future<BackendToolCallResponse> callTool(
    String name,
    Map<String, Object?> arguments,
  ) async {
    final socket = _socket;
    if (socket == null) {
      return const BackendToolCallResponse(
        isError: true,
        message: notRunningMessage,
      );
    }
    final response = await socket.postJson(
      '/api/v1/internal/mcp/tools/${Uri.encodeComponent(name)}',
      McpToolCallRequest(arguments: arguments, cwd: _cwd).toJson(),
      timeout: timeoutFor(name),
    );
    if (response.backendUnreachable) {
      return const BackendToolCallResponse(
        isError: true,
        message: notRunningMessage,
      );
    }
    if (response.isError) {
      return response;
    }
    try {
      final decoded = jsonDecode(response.message);
      if (decoded is Map<String, Object?>) {
        return BackendToolCallResponse(
          isError: false,
          message: McpToolCallResponse.fromJson(decoded).text,
        );
      }
    } on Object {
      // Fall through to the raw body.
    }
    return response;
  }
}
