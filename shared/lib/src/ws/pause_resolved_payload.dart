import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/pauses/pause.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pause_resolved_payload.freezed.dart';
part 'pause_resolved_payload.g.dart';

/// Payload of a `pause.resolved` WebSocket message.
@freezed
sealed class PauseResolvedPayload with _$PauseResolvedPayload {
  /// Creates a pause-resolved payload.
  const factory({required Pause pause}) = _PauseResolvedPayload;

  /// Decodes a pause-resolved payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$PauseResolvedPayloadFromJson);
}
