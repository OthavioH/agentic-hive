import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_subscribe_payload.freezed.dart';
part 'run_subscribe_payload.g.dart';

/// Payload of a `run.subscribe` WebSocket message.
@freezed
sealed class RunSubscribePayload with _$RunSubscribePayload {
  /// Creates a run-subscribe payload.
  const factory({required String runId}) = _RunSubscribePayload;

  /// Decodes a run-subscribe payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RunSubscribePayloadFromJson);
}
