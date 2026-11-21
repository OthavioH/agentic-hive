import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_summary.freezed.dart';
part 'agent_summary.g.dart';

/// Summary of an agent `.md` file in the library.
@freezed
sealed class AgentSummary with _$AgentSummary {
  /// Creates an agent summary.
  const factory({
    required String id,
    required String name,
    required String contentHash,
    required DateTime updatedAt,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    String? parseError,
  }) = _AgentSummary;

  /// Decodes an agent summary; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$AgentSummaryFromJson);
}
