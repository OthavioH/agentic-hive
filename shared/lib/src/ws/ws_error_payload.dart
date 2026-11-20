import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ws_error_payload.freezed.dart';
part 'ws_error_payload.g.dart';

/// Payload of an `error` message.
@freezed
sealed class WsErrorPayload with _$WsErrorPayload {
  /// Creates an error payload.
  const factory({
    required String code,
    required String message,
    String? replyTo,
  }) = _WsErrorPayload;

  /// Decodes an error payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WsErrorPayloadFromJson);
}

/// Error codes sent in [WsErrorPayload.code].
abstract final class WsErrorCode {
  /// The frame was not a valid envelope (not JSON, or missing fields).
  static const invalidMessage = 'invalid_message';

  /// The envelope was valid, but its `type` is not handled.
  static const unknownMessageType = 'unknown_message_type';
}
