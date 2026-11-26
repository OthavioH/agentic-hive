import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists runs with optional status, workflow, workspace, and pagination
/// filters.
final class ListRuns {
  /// Creates a [ListRuns] use case backed by [_repository].
  const new(this._repository);

  final RunRepository _repository;

  /// Executes the use case.
  Future<Result<RunsListResponse>> call({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) => _repository.listRuns(
    status: status,
    workflowId: workflowId,
    workspaceId: workspaceId,
    limit: limit,
    offset: offset,
  );
}
