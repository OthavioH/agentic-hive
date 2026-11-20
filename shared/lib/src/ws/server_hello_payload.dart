import 'package:agentic_hive_shared/src/json_fields.dart';

/// Payload of a `server.hello` message.
final class ServerHelloPayload {
  /// Creates a hello payload.
  const new({required this.serverVersion, required this.protocolVersion});

  /// Decodes a hello payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => ServerHelloPayload(
    serverVersion: readField<String>(json, 'serverVersion'),
    protocolVersion: readField<int>(json, 'protocolVersion'),
  );

  /// Backend version, such as `0.1.0`.
  final String serverVersion;

  /// The WebSocket protocol version the server speaks.
  final int protocolVersion;

  /// Encodes this payload as JSON.
  JsonMap toJson() => {
    'serverVersion': serverVersion,
    'protocolVersion': protocolVersion,
  };
}
