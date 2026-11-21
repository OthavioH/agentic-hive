import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_detail.freezed.dart';
part 'agent_detail.g.dart';

/// Full representation of an agent `.md` file, including prompt and metadata.
@freezed
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
    String? parseError,
    String? rawContent,
  }) = _AgentDetail;

  /// Decodes an agent detail; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$AgentDetailFromJson);
}
