import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pty_resize_payload.freezed.dart';
part 'pty_resize_payload.g.dart';

/// Payload of a `pty.resize` WebSocket message.
@freezed
sealed class PtyResizePayload with _$PtyResizePayload {
  /// Creates a PTY-resize payload.
  const factory({
    required String runId,
    required String nodeId,
    required int attempt,
    required int cols,
    required int rows,
  }) = _PtyResizePayload;

  /// Decodes a PTY-resize payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$PtyResizePayloadFromJson);
}
