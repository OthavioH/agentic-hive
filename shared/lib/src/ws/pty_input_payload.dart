import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pty_input_payload.freezed.dart';
part 'pty_input_payload.g.dart';

/// Payload of a `pty.input` WebSocket message.
///
/// [data] contains base64-encoded raw keystroke/paste bytes to write to the
/// active PTY's input stream.
@freezed
sealed class PtyInputPayload with _$PtyInputPayload {
  /// Creates a PTY-input payload.
  const factory({
    required String runId,
    required String nodeId,
    required int attempt,
    required String data,
  }) = _PtyInputPayload;

  /// Decodes a PTY-input payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$PtyInputPayloadFromJson);
}
