import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
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

  /// Deletes the workflow [id] of [workspaceId] (global when `null`) as an
  /// asynchronous operation (ADR 0027) and reports it: a
  /// [WorkflowDeletionStarted] on `202`, [WorkflowDeletionProgressed] while it
  /// runs, then exactly one [WorkflowDeletionEnded], after which the stream
  /// closes. [revision] is the expected revision; [force] stops active runs
  /// first.
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    String? workspaceId,
    String? revision,
    bool force = false,
  });

  /// Validates [workflow] without persisting changes.
  Future<Result<WorkflowValidationResult>> validateWorkflow(Workflow workflow);
}
