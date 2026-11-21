import 'package:agentic_hive_shared/src/agents/agent_summary.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_list_response.freezed.dart';
part 'agent_list_response.g.dart';

/// Body of `GET /api/v1/agents`.
@freezed
sealed class AgentListResponse with _$AgentListResponse {
  /// Creates an agent list response.
  const factory({required List<AgentSummary> agents}) = _AgentListResponse;

  /// Decodes an agent list response; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$AgentListResponseFromJson);
}
