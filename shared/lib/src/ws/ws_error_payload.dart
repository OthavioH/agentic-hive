import 'package:agentic_hive_shared/src/json_fields.dart';

/// Payload of an `error` message.
final class WsErrorPayload {
  /// Creates an error payload.
  const new({required this.code, required this.message, this.replyTo});

  /// Decodes an error payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => WsErrorPayload(
    code: readField<String>(json, 'code'),
    message: readField<String>(json, 'message'),
    replyTo: readField<String?>(json, 'replyTo'),
  );

  /// A stable error code from [WsErrorCode].
  final String code;

  /// A human-readable description of the problem.
  final String message;

  /// The `id` of the client message this error answers, when it had one.
  final String? replyTo;

  /// Encodes this payload as JSON.
  JsonMap toJson() => {'code': code, 'message': message, 'replyTo': ?replyTo};
}

/// Error codes sent in [WsErrorPayload.code].
abstract final class WsErrorCode {
  /// The frame was not a valid envelope (not JSON, or missing fields).
  static const invalidMessage = 'invalid_message';

  /// The envelope was valid, but its `type` is not handled.
  static const unknownMessageType = 'unknown_message_type';
}
