import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'shutdown_response.freezed.dart';
part 'shutdown_response.g.dart';

/// Response body of `POST /api/v1/shutdown` when shutdown is accepted (`202`).
@freezed
sealed class ShutdownResponse with _$ShutdownResponse {
  /// Creates a shutdown response body.
  const factory({@Default('shutting_down') String status}) = _ShutdownResponse;

  /// Decodes a shutdown response body; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) => parseJson(json, _$ShutdownResponseFromJson);
}
