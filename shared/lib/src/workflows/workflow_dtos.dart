import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workflows/workflow.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_edge.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_node.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_summary.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_validation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_dtos.freezed.dart';
part 'workflow_dtos.g.dart';

/// Request body for `POST /api/v1/workflows`.
@freezed
sealed class CreateWorkflowRequest with _$CreateWorkflowRequest {
  /// Creates a create-workflow request.
  const factory({
    required String name,
    String? description,
    @Default(<WorkflowNode>[]) List<WorkflowNode> nodes,
    @Default(<WorkflowEdge>[]) List<WorkflowEdge> edges,
    String? entryNodeId,
    @Default(1) int schemaVersion,
  }) = _CreateWorkflowRequest;

  /// Decodes a create-workflow request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$CreateWorkflowRequestFromJson);
}

/// Request body for `PUT /api/v1/workflows/:id`.
@freezed
sealed class UpdateWorkflowRequest with _$UpdateWorkflowRequest {
  /// Creates an update-workflow request.
  const factory({
    required String name,
    String? description,
    @Default(<WorkflowNode>[]) List<WorkflowNode> nodes,
    @Default(<WorkflowEdge>[]) List<WorkflowEdge> edges,
    String? entryNodeId,
    @Default(1) int schemaVersion,
  }) = _UpdateWorkflowRequest;

  /// Decodes an update-workflow request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$UpdateWorkflowRequestFromJson);
}

/// Optional request body for `POST /api/v1/workflows/:id/duplicate`.
@freezed
sealed class DuplicateWorkflowRequest with _$DuplicateWorkflowRequest {
  /// Creates a duplicate-workflow request.
  const factory({String? name}) = _DuplicateWorkflowRequest;

  /// Decodes a duplicate-workflow request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$DuplicateWorkflowRequestFromJson);
}

/// Request body for `POST /api/v1/workflows/validate`.
@freezed
sealed class ValidateWorkflowRequest with _$ValidateWorkflowRequest {
  /// Creates a validate-workflow request.
  const factory({required Workflow workflow}) = _ValidateWorkflowRequest;

  /// Decodes a validate-workflow request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$ValidateWorkflowRequestFromJson);
}

/// Response body for `GET /api/v1/workflows`.
@freezed
sealed class WorkflowListResponse with _$WorkflowListResponse {
  /// Creates a workflow-list response.
  const factory({required List<WorkflowSummary> workflows}) =
      _WorkflowListResponse;

  /// Decodes a workflow-list response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkflowListResponseFromJson);
}

/// Response body for single-workflow endpoints (`POST`, `GET`, `PUT`,
/// `duplicate`).
@freezed
sealed class WorkflowResponse with _$WorkflowResponse {
  /// Creates a workflow response.
  const factory({
    required Workflow workflow,
    required WorkflowValidationResult validation,
  }) = _WorkflowResponse;

  /// Decodes a workflow response; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorkflowResponseFromJson);
}
