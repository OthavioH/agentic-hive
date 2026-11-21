import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_agent_request.freezed.dart';
part 'update_agent_request.g.dart';

/// Body of `PUT /api/v1/agents/<id>`.
@freezed
sealed class UpdateAgentRequest with _$UpdateAgentRequest {
  /// Creates a request to update an existing agent `.md` file.
  const factory({
    required String name,
    required String expectedHash,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default(<String>[]) List<String> requiredSkills,
    @Default(<String>[]) List<String> requiredTools,
    @Default(<String>[]) List<String> allowedTools,
    @Default(<String>[]) List<String> deniedTools,
    @Default('') String prompt,
  }) = _UpdateAgentRequest;

  /// Decodes an update-agent request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$UpdateAgentRequestFromJson);
}
