import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Validates a workflow graph without persisting it.
final class ValidateWorkflow {
  /// Creates a [ValidateWorkflow] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case for [workflow].
  Future<Result<WorkflowValidationResult>> call(Workflow workflow) =>
      _repository.validateWorkflow(workflow);
}
