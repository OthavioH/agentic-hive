import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';

/// Deletes a workflow by ID as an asynchronous operation (ADR 0027).
final class DeleteWorkflow {
  /// Creates a [DeleteWorkflow] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case for [id] in the scope of [workspaceId]. [revision]
  /// is the expected revision; [force] stops active runs first.
  Stream<WorkflowDeletionUpdate> call(
    String id, {
    String? workspaceId,
    String? revision,
    bool force = false,
  }) => _repository.deleteWorkflow(
    id,
    workspaceId: workspaceId,
    revision: revision,
    force: force,
  );
}
