import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_edge.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_node.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow.freezed.dart';
part 'workflow.g.dart';

/// A saved workflow graph definition (recipe).
@freezed
sealed class Workflow with _$Workflow {
  /// Creates a workflow definition.
  const factory({
    required String id,
    required String name,
    required List<WorkflowNode> nodes,
    required List<WorkflowEdge> edges,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? description,
    String? entryNodeId,
    @Default(1) int schemaVersion,
  }) = _Workflow;

  /// Decodes a workflow; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorkflowFromJson);
}
