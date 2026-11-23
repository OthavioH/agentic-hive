import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists all saved workflow summaries.
final class ListWorkflows {
  /// Creates a [ListWorkflows] use case backed by [_repository].
  const new(this._repository);

  final WorkflowRepository _repository;

  /// Executes the use case: global workflows, plus those of [workspaceId].
  Future<Result<List<WorkflowSummary>>> call({String? workspaceId}) =>
      _repository.listWorkflows(workspaceId: workspaceId);
}
