import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';

/// Deletes a workflow by ID.
final class DeleteWorkflow {
  /// Creates a [DeleteWorkflow] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case for [id] in the scope of [workspaceId].
  Future<Result<void>> call(String id, {String? workspaceId}) =>
      _repository.deleteWorkflow(id, workspaceId: workspaceId);
}
