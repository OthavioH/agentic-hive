import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for managing saved workflow definitions.
abstract interface class WorkflowRepository {
  /// Returns summaries of all saved workflows.
  Future<Result<List<WorkflowSummary>>> listWorkflows();

  /// Fetches a single workflow and its current validation result by [id].
  Future<Result<WorkflowResponse>> getWorkflow(String id);

  /// Creates and persists a new workflow.
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  );

  /// Updates an existing workflow identified by [id].
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request,
  );

  /// Duplicates an existing workflow identified by [id].
  Future<Result<WorkflowResponse>> duplicateWorkflow(String id, {String? name});

  /// Deletes the workflow identified by [id].
  Future<Result<void>> deleteWorkflow(String id);

  /// Validates [workflow] without persisting changes.
  Future<Result<WorkflowValidationResult>> validateWorkflow(Workflow workflow);
}
