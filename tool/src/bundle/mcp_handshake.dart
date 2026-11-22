import 'dart:convert';

/// JSON-RPC id of the smoke test's MCP `initialize` request.
const mcpInitializeRequestId = 1;

/// MCP protocol version the smoke test asks for (supported by dart_mcp 0.5.x).
const mcpSmokeProtocolVersion = '2025-06-18';

/// One newline-free JSON-RPC `initialize` request line for an MCP stdio server.
String mcpInitializeRequestLine() => jsonEncode({
  'jsonrpc': '2.0',
  'id': mcpInitializeRequestId,
  'method': 'initialize',
  'params': {
    'protocolVersion': mcpSmokeProtocolVersion,
    'capabilities': <String, Object?>{},
    'clientInfo': {'name': 'smoke_bundle', 'version': '0'},
  },
});

/// The JSON object on [line], or `null` when the line is not a JSON object.
Map<String, Object?>? decodeJsonRpcLine(String line) {
  try {
    final decoded = jsonDecode(line);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Whether [message] is the reply to the smoke test's `initialize` request.
bool isInitializeReply(Map<String, Object?> message) =>
    message['id'] == mcpInitializeRequestId;

/// Why [reply] is not a successful `initialize` result, or `null` when it is.
String? initializeReplyProblem(Map<String, Object?> reply) {
  final error = reply['error'];
  if (error is Map) {
    return 'error ${error['code']}: ${error['message']}';
  }
  final result = reply['result'];
  if (result is! Map) {
    return 'reply has no result object';
  }
  if (result['protocolVersion'] is! String) {
    return 'result has no protocolVersion';
  }
  return null;
}
