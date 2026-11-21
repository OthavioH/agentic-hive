import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_unsubscribe_payload.freezed.dart';
part 'run_unsubscribe_payload.g.dart';

/// Payload of a `run.unsubscribe` WebSocket message.
@freezed
sealed class RunUnsubscribePayload with _$RunUnsubscribePayload {
  /// Creates a run-unsubscribe payload.
  const factory({required String runId}) = _RunUnsubscribePayload;

  /// Decodes a run-unsubscribe payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RunUnsubscribePayloadFromJson);
}
