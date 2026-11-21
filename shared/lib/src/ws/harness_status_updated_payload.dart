import 'package:agentic_hive_shared/src/harnesses/harness_info.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'harness_status_updated_payload.freezed.dart';
part 'harness_status_updated_payload.g.dart';

/// Payload of a `harness.status_updated` WebSocket message.
@freezed
sealed class HarnessStatusUpdatedPayload with _$HarnessStatusUpdatedPayload {
  /// Creates a harness status updated payload.
  const factory({required HarnessInfo harness}) = _HarnessStatusUpdatedPayload;

  /// Decodes a harness status updated payload; throws a [FormatException] on a
  /// bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$HarnessStatusUpdatedPayloadFromJson);
}
