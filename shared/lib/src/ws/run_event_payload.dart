import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/run_event.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_event_payload.freezed.dart';
part 'run_event_payload.g.dart';

/// Payload of a `run.event` WebSocket message.
@freezed
sealed class RunEventPayload with _$RunEventPayload {
  /// Creates a run-event payload.
  const factory({required RunEvent event}) = _RunEventPayload;

  /// Decodes a run-event payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunEventPayloadFromJson);
}
