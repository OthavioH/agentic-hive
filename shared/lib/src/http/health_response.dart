import 'package:agentic_hive_shared/src/json_fields.dart';

/// Body of `GET /health`: tells that the backend process is up.
final class HealthResponse {
  /// Creates a health body.
  const new({this.status = 'ok'});

  /// Decodes a health body; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      HealthResponse(status: readField<String>(json, 'status'));

  /// Always `ok` when the backend answers.
  final String status;

  /// Encodes this body as JSON.
  JsonMap toJson() => {'status': status};
}
