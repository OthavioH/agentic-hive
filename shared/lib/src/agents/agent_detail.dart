import 'package:agentic_hive_shared/src/definitions/definition_scope.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_detail.freezed.dart';
part 'agent_detail.g.dart';

/// Full representation of an agent `.md` file, including prompt and metadata.
@Freezed(toJson: false)
sealed class AgentDetail with _$AgentDetail {
  /// Creates an agent detail.
  const factory({
    required String id,
    required String name,
    required String contentHash,
    required DateTime updatedAt,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default(<String>[]) List<String> requiredSkills,
    @Default(<String>[]) List<String> requiredTools,
    @Default(<String>[]) List<String> allowedTools,
    @Default(<String>[]) List<String> deniedTools,
    @Default('') String prompt,
    @Default(GlobalScope())
    @JsonKey(
      readValue: readWholeJson,
      fromJson: DefinitionScope.fromJson,
      includeToJson: false,
    )
    DefinitionScope scope,
    String? parseError,
    String? rawContent,
  }) = _AgentDetail;

  const new _();

  /// Decodes an agent detail; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$AgentDetailFromJson);

  /// Encodes this detail to JSON, flattening [scope] into `scope` and
  /// optional `workspaceId`.
  JsonMap toJson() => {
    'id': id,
    'name': name,
    'contentHash': contentHash,
    'updatedAt': updatedAt.toIso8601String(),
    'description': description,
    'tags': tags,
    'requiredSkills': requiredSkills,
    'requiredTools': requiredTools,
    'allowedTools': allowedTools,
    'deniedTools': deniedTools,
    'prompt': prompt,
    'parseError': ?parseError,
    'rawContent': ?rawContent,
    ...scope.toJson(),
  };
}
