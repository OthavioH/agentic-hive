import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_edge.freezed.dart';
part 'workflow_edge.g.dart';

/// A directed transition between two nodes in a workflow graph.
@freezed
sealed class WorkflowEdge with _$WorkflowEdge {
  /// Creates a workflow edge.
  const factory({
    required String id,
    required String sourceNodeId,
    required String sourceOutput,
    required String targetNodeId,
    int? maxRetries,
  }) = _WorkflowEdge;

  /// Decodes a workflow edge; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorkflowEdgeFromJson);
}
