import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pty_output_payload.freezed.dart';
part 'pty_output_payload.g.dart';

/// Payload of a `pty.output` WebSocket message.
///
/// [data] contains base64-encoded raw PTY bytes so ANSI escape sequences and
/// partial multi-byte UTF-8 sequences are preserved intact across chunks.
@freezed
sealed class PtyOutputPayload with _$PtyOutputPayload {
  /// Creates a PTY-output payload.
  const factory({
    required String runId,
    required String nodeId,
    required int attempt,
    required String data,
    required DateTime timestamp,
    @Default(false) bool isSnapshot,
  }) = _PtyOutputPayload;

  /// Decodes a PTY-output payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$PtyOutputPayloadFromJson);
}
