import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for managing saved workflow definitions.
abstract interface class WorkflowRepository {
  /// Returns summaries of the global workflows, plus the ones of
  /// [WorkspaceScope] when given. Each summary carries its scope.
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  });

  /// Fetches a single workflow and its current validation result by [id], in
  /// [scope].
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  });

  /// Creates and persists a new workflow.
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  );

  /// Updates an existing workflow identified by [id] in [scope].
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  });

  /// Duplicates an existing workflow identified by [id] inside [scope].
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  });

  /// Deletes the workflow [id] of [scope] as an
  /// asynchronous operation (ADR 0027) and reports it: a
  /// [WorkflowDeletionStarted] on `202`, [WorkflowDeletionProgressed] while it
  /// runs, then exactly one [WorkflowDeletionEnded], after which the stream
  /// closes. [revision] is the expected revision; [force] stops active runs
  /// first.
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  });

  /// Validates [workflow] without persisting changes.
  Future<Result<WorkflowValidationResult>> validateWorkflow(Workflow workflow);
}
