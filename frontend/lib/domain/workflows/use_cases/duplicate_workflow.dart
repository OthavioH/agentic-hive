import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Duplicates an existing workflow.
final class DuplicateWorkflow {
  /// Creates a [DuplicateWorkflow] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case for [id] with an optional override [name], inside
  /// the scope of [workspaceId].
  Future<Result<WorkflowResponse>> call(
    String id, {
    String? name,
    String? workspaceId,
  }) => _repository.duplicateWorkflow(id, name: name, workspaceId: workspaceId);
}
