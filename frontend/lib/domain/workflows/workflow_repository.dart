import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for managing saved workflow definitions.
abstract interface class WorkflowRepository {
  /// Returns summaries of the global workflows, plus the ones of
  /// [workspaceId] when given. Each summary carries its scope.
  Future<Result<List<WorkflowSummary>>> listWorkflows({String? workspaceId});

  /// Fetches a single workflow and its current validation result by [id], in
  /// the scope of [workspaceId] (global when `null`).
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  });

  /// Creates and persists a new workflow.
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  );

  /// Updates an existing workflow identified by [id] in the scope of
  /// [workspaceId] (global when `null`).
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  });

  /// Duplicates an existing workflow identified by [id] inside its scope.
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  });

  /// Deletes the workflow identified by [id] in the scope of [workspaceId]
  /// (global when `null`).
  Future<Result<void>> deleteWorkflow(String id, {String? workspaceId});

  /// Validates [workflow] without persisting changes.
  Future<Result<WorkflowValidationResult>> validateWorkflow(Workflow workflow);
}
