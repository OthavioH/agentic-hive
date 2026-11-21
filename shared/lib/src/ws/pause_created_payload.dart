import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/pauses/pause.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pause_created_payload.freezed.dart';
part 'pause_created_payload.g.dart';

/// Payload of a `pause.created` WebSocket message.
@freezed
sealed class PauseCreatedPayload with _$PauseCreatedPayload {
  /// Creates a pause-created payload.
  const factory({required Pause pause}) = _PauseCreatedPayload;

  /// Decodes a pause-created payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$PauseCreatedPayloadFromJson);
}
