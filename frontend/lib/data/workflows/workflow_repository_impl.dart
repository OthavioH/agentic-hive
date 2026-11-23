import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [WorkflowRepository] backed by [WorkflowRemoteDataSource].
final class WorkflowRepositoryImpl implements WorkflowRepository {
  /// Creates a [WorkflowRepositoryImpl] delegating to [_remoteDataSource].
  const new(this._remoteDataSource);

  final WorkflowRemoteDataSource _remoteDataSource;

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows() =>
      _remoteDataSource.listWorkflows();

  @override
  Future<Result<WorkflowResponse>> getWorkflow(String id) =>
      _remoteDataSource.getWorkflow(id);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) => _remoteDataSource.createWorkflow(request);

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request,
  ) => _remoteDataSource.updateWorkflow(id, request);

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
  }) => _remoteDataSource.duplicateWorkflow(id, name: name);

  @override
  Future<Result<void>> deleteWorkflow(String id) =>
      _remoteDataSource.deleteWorkflow(id);

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) => _remoteDataSource.validateWorkflow(workflow);
}
