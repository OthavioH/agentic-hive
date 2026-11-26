import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Updates an existing workflow.
final class UpdateWorkflow {
  /// Creates an [UpdateWorkflow] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case for [id] with [request] in [scope].
  Future<Result<WorkflowResponse>> call(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) => _repository.updateWorkflow(id, request, scope: scope);
}
