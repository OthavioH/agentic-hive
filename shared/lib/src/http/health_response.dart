import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_response.freezed.dart';
part 'health_response.g.dart';

/// Body of `GET /health`: tells that the backend process is up.
@freezed
sealed class HealthResponse with _$HealthResponse {
  /// Creates a health body.
  const factory({@Default('ok') String status}) = _HealthResponse;

  /// Decodes a health body; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$HealthResponseFromJson);
}
