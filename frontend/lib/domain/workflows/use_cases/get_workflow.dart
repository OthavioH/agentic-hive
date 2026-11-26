import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches a workflow and its validation status by ID.
final class GetWorkflow {
  /// Creates a [GetWorkflow] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case for [id] in [scope].
  Future<Result<WorkflowResponse>> call(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) => _repository.getWorkflow(id, scope: scope);
}
