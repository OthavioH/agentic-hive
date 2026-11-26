import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Deletes a workflow by ID as an asynchronous operation (ADR 0027).
final class DeleteWorkflow {
  /// Creates a [DeleteWorkflow] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case for [id] in [scope]. [revision]
  /// is the expected revision; [force] stops active runs first.
  Stream<WorkflowDeletionUpdate> call(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) => _repository.deleteWorkflow(
    id,
    scope: scope,
    revision: revision,
    force: force,
  );
}
