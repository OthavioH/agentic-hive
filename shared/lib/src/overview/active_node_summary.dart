import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/overview/active_node_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'active_node_summary.freezed.dart';
part 'active_node_summary.g.dart';

/// Summary of a currently executing or paused node in an active run.
@freezed
sealed class ActiveNodeSummary with _$ActiveNodeSummary {
  /// Creates an active node summary.
  const factory({
    required String runId,
    required String workflowName,
    required String nodeId,
    required String nodeType,
    required String nodeLabel,
    required ActiveNodeStatus status,
    required DateTime startedAt,
    String? agentId,
    String? agentName,
  }) = _ActiveNodeSummary;

  /// Decodes an active node summary; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$ActiveNodeSummaryFromJson);
}
