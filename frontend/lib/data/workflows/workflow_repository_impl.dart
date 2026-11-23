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
  Future<Result<List<WorkflowSummary>>> listWorkflows({String? workspaceId}) =>
      _remoteDataSource.listWorkflows(workspaceId: workspaceId);

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) => _remoteDataSource.getWorkflow(id, workspaceId: workspaceId);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) => _remoteDataSource.createWorkflow(request);

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) => _remoteDataSource.updateWorkflow(id, request, workspaceId: workspaceId);

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) => _remoteDataSource.duplicateWorkflow(
    id,
    name: name,
    workspaceId: workspaceId,
  );

  @override
  Future<Result<void>> deleteWorkflow(String id, {String? workspaceId}) =>
      _remoteDataSource.deleteWorkflow(id, workspaceId: workspaceId);

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) => _remoteDataSource.validateWorkflow(workflow);
}
