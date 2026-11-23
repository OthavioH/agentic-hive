import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'shutdown_request.freezed.dart';
part 'shutdown_request.g.dart';

/// Request body of `POST /api/v1/shutdown`.
@freezed
sealed class ShutdownRequest with _$ShutdownRequest {
  /// Creates a shutdown request body.
  const factory({@Default(false) bool force}) = _ShutdownRequest;

  /// Decodes a shutdown request body; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) => parseJson(json, _$ShutdownRequestFromJson);
}
