import 'package:agentic_hive_shared/src/harnesses/harness_info.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'harness_list_response.freezed.dart';
part 'harness_list_response.g.dart';

/// Body of `GET /api/v1/harnesses` and `POST /api/v1/harnesses/refresh`.
@freezed
sealed class HarnessListResponse with _$HarnessListResponse {
  /// Creates a harness list response.
  const factory({required List<HarnessInfo> harnesses}) = _HarnessListResponse;

  /// Decodes a harness list response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$HarnessListResponseFromJson);
}
