import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/run_event_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_event.freezed.dart';
part 'run_event.g.dart';

/// One append-only entry in a run's event log.
@freezed
sealed class RunEvent with _$RunEvent {
  /// Creates a run event.
  const factory({
    required String id,
    required String runId,
    required int sequence,
    required RunEventType type,
    required DateTime createdAt,
    String? nodeId,
    String? edgeId,
    @Default(<String, Object?>{}) JsonMap payload,
  }) = _RunEvent;

  /// Decodes a run event; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunEventFromJson);
}
