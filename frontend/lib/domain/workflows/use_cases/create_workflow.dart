import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Creates a new workflow.
final class CreateWorkflow {
  /// Creates a [CreateWorkflow] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case with [request].
  Future<Result<WorkflowResponse>> call(CreateWorkflowRequest request) =>
      _repository.createWorkflow(request);
}
