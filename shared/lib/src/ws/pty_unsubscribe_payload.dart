import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pty_unsubscribe_payload.freezed.dart';
part 'pty_unsubscribe_payload.g.dart';

/// Payload of a `pty.unsubscribe` WebSocket message.
@freezed
sealed class PtyUnsubscribePayload with _$PtyUnsubscribePayload {
  /// Creates a PTY-unsubscribe payload.
  const factory({
    required String runId,
    required String nodeId,
    @Default(1) int attempt,
  }) = _PtyUnsubscribePayload;

  /// Decodes a PTY-unsubscribe payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$PtyUnsubscribePayloadFromJson);
}
