import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source for workflow CRUD and validation over the backend REST
/// API.
abstract interface class WorkflowRemoteDataSource {
  /// Fetches workflow summaries (`GET /api/v1/workflows`): global ones, plus
  /// those of [WorkspaceScope] when given.
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  });

  /// Fetches a single workflow and its validation status by [id]
  /// (`GET /api/v1/workflows/:id`) in [scope].
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  });

  /// Creates a new workflow (`POST /api/v1/workflows`).
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  );

  /// Updates an existing workflow (`PUT /api/v1/workflows/:id`) in [scope].
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  });

  /// Duplicates an existing workflow (`POST /api/v1/workflows/:id/duplicate`).
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  });

  /// Starts deleting a workflow (`DELETE /api/v1/workflows/:id`, `202`).
  /// [revision] is the expected revision; [force] stops active runs first.
  Future<Result<WorkflowDeletionAccepted>> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  });

  /// Reads workflow deletion operation status.
  Future<Result<WorkflowDeletionStatus>> getWorkflowDeletion(
    String operationId,
  );

  /// Validates [workflow] without persisting (`POST /api/v1/workflows/validate`).
  Future<Result<WorkflowValidationResult>> validateWorkflow(Workflow workflow);
}

/// [WorkflowRemoteDataSource] backed by [BackendClient].
final class HttpWorkflowRemoteDataSource implements WorkflowRemoteDataSource {
  /// Creates an HTTP workflow data source using [_client].
  const new(this._client);

  static const String _basePath = '/api/v1/workflows';

  final BackendClient _client;

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final result = await _client.sendJsonRequest(
      'GET',
      '$_basePath${_scopeQuery(scope)}',
    );
    return _decode(
      result,
      (json) => WorkflowListResponse.fromJson(json).workflows,
    );
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'GET',
      '$_basePath/$encodedId${_scopeQuery(scope)}',
    );
    return _decode(result, WorkflowResponse.fromJson);
  }

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async {
    final result = await _client.sendJsonRequest(
      'POST',
      _basePath,
      body: request.toJson(),
    );
    return _decode(result, WorkflowResponse.fromJson);
  }

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'PUT',
      '$_basePath/$encodedId${_scopeQuery(scope)}',
      body: request.toJson(),
    );
    return _decode(result, WorkflowResponse.fromJson);
  }

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'POST',
      '$_basePath/$encodedId/duplicate${_scopeQuery(scope)}',
      body: name == null ? null : DuplicateWorkflowRequest(name: name).toJson(),
    );
    return _decode(result, WorkflowResponse.fromJson);
  }

  @override
  Future<Result<WorkflowDeletionAccepted>> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) async {
    final encodedId = Uri.encodeComponent(id);
    final workspaceId = scope.workspaceIdOrNull;
    final query = <String, String>{
      'workspaceId': ?workspaceId,
      'revision': ?revision,
      if (force) 'force': 'true',
    };
    final result = await _client.sendJsonRequest(
      'DELETE',
      '$_basePath/$encodedId${query.isEmpty ? '' : '?${Uri(queryParameters: query).query}'}',
    );
    return _decode(result, WorkflowDeletionAccepted.fromJson);
  }

  @override
  Future<Result<WorkflowDeletionStatus>> getWorkflowDeletion(
    String operationId,
  ) async {
    final result = await _client.sendJsonRequest(
      'GET',
      '/api/v1/workflow-deletions/${Uri.encodeComponent(operationId)}',
    );
    return _decode(result, WorkflowDeletionStatus.fromJson);
  }

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async {
    final result = await _client.sendJsonRequest(
      'POST',
      '$_basePath/validate',
      body: ValidateWorkflowRequest(workflow: workflow).toJson(),
    );
    return _decode(result, WorkflowValidationResult.fromJson);
  }

  String _scopeQuery(DefinitionScope scope) => switch (scope) {
    GlobalScope() => '',
    WorkspaceScope(:final workspaceId) =>
      '?workspaceId=${Uri.encodeQueryComponent(workspaceId)}',
  };

  Result<T> _decode<T>(
    Result<JsonMap> result,
    T Function(JsonMap json) parser,
  ) {
    return result.flatMap((json) {
      try {
        return Success<T>(parser(json));
      } on FormatException catch (error) {
        return FailureResult<T>(
          BackendFailure('Invalid workflow payload: ${error.message}'),
        );
      }
    });
  }
}
