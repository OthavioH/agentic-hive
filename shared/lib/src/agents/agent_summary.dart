import 'package:agentic_hive_shared/src/definitions/definition_scope.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_summary.freezed.dart';
part 'agent_summary.g.dart';

/// Summary of an agent `.md` file in the library.
///
/// [scope] says where the file lives. [overridden] is true for a global agent
/// shadowed by a workspace agent with the same `name` in the same listing.
@Freezed(toJson: false)
sealed class AgentSummary with _$AgentSummary {
  /// Creates an agent summary.
  const factory({
    required String id,
    required String name,
    required String contentHash,
    required DateTime updatedAt,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default(GlobalScope())
    @JsonKey(
      readValue: readWholeJson,
      fromJson: DefinitionScope.fromJson,
      includeToJson: false,
    )
    DefinitionScope scope,
    @Default(false) bool overridden,
    String? parseError,
  }) = _AgentSummary;

  const new _();

  /// Decodes an agent summary; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$AgentSummaryFromJson);

  /// Encodes this summary to JSON, flattening [scope] into `scope` and
  /// optional `workspaceId`.
  JsonMap toJson() => {
    'id': id,
    'name': name,
    'contentHash': contentHash,
    'updatedAt': updatedAt.toIso8601String(),
    'description': description,
    'tags': tags,
    'overridden': overridden,
    'parseError': ?parseError,
    ...scope.toJson(),
  };
}
