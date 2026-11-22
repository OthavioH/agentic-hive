import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pty_subscribe_payload.freezed.dart';
part 'pty_subscribe_payload.g.dart';

/// Payload of a `pty.subscribe` WebSocket message.
@freezed
sealed class PtySubscribePayload with _$PtySubscribePayload {
  /// Creates a PTY-subscribe payload.
  const factory({
    required String runId,
    required String nodeId,
    @Default(1) int attempt,
  }) = _PtySubscribePayload;

  /// Decodes a PTY-subscribe payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$PtySubscribePayloadFromJson);
}
