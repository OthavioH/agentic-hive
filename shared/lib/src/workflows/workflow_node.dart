import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_position.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_node.freezed.dart';
part 'workflow_node.g.dart';

/// One step in a workflow graph.
@freezed
sealed class WorkflowNode with _$WorkflowNode {
  /// Creates a workflow node.
  const factory({
    required String id,
    required String type,
    required String label,
    required WorkflowPosition position,
    @Default(<String, Object?>{}) JsonMap config,
  }) = _WorkflowNode;

  /// Decodes a workflow node; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorkflowNodeFromJson);
}
