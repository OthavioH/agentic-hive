import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_reference_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches workflows whose fan-out nodes reference a target workflow.
final class GetWorkflowReferences {
  /// Creates a [GetWorkflowReferences] use case.
  const new(this._repository);

  final WorkflowReferenceRepository _repository;

  /// Returns workflows referencing [workflowId] in [scope].
  Future<Result<List<WorkflowReference>>> call(
    String workflowId, {
    DefinitionScope scope = const GlobalScope(),
  }) => _repository.getReferences(workflowId, scope: scope);
}
