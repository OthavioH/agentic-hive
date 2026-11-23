import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_agent_request.freezed.dart';
part 'create_agent_request.g.dart';

/// Body of `POST /api/v1/agents`.
@freezed
sealed class CreateAgentRequest with _$CreateAgentRequest {
  /// Creates a request to create a new agent `.md` file.
  const factory({
    required String id,
    required String name,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default(<String>[]) List<String> requiredSkills,
    @Default(<String>[]) List<String> requiredTools,
    @Default(<String>[]) List<String> allowedTools,
    @Default(<String>[]) List<String> deniedTools,
    @Default('') String prompt,
  }) = _CreateAgentRequest;

  /// Decodes a create-agent request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$CreateAgentRequestFromJson);
}
