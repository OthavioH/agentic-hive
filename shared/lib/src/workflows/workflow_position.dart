import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_position.freezed.dart';
part 'workflow_position.g.dart';

/// 2D canvas coordinates for a workflow node.
@freezed
sealed class WorkflowPosition with _$WorkflowPosition {
  /// Creates a canvas position at ([x], [y]).
  const factory({required double x, required double y}) = _WorkflowPosition;

  /// Decodes a position; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorkflowPositionFromJson);
}
