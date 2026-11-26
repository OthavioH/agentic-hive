import 'package:agentic_hive_shared/src/definitions/definition_scope.dart';
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

    /// Workspace that owns the workflow; `null` creates a global workflow.
    String? workspaceId,
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

    /// Revision the client read; when set the backend answers 409
    /// `revision_conflict` if the workflow changed since.
    String? revision,
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
@Freezed(toJson: false)
sealed class WorkflowResponse with _$WorkflowResponse {
  /// Creates a workflow response.
  const factory({
    required Workflow workflow,
    required WorkflowValidationResult validation,
    @Default(GlobalScope())
    @JsonKey(
      readValue: readWholeJson,
      fromJson: DefinitionScope.fromJson,
      includeToJson: false,
    )
    DefinitionScope scope,

    /// Content hash of the workflow definition for optimistic concurrency;
    /// always set by the backend.
    String? revision,
  }) = _WorkflowResponse;

  const new _();

  /// Decodes a workflow response; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorkflowResponseFromJson);

  /// Encodes this response to JSON, flattening [scope] into `scope` and
  /// optional `workspaceId`.
  JsonMap toJson() => {
    'workflow': workflow.toJson(),
    'validation': validation.toJson(),
    'revision': ?revision,
    ...scope.toJson(),
  };
}
