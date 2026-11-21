import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source for workflow CRUD and validation over the backend REST
/// API.
abstract interface class WorkflowRemoteDataSource {
  /// Fetches all workflow summaries (`GET /api/v1/workflows`).
  Future<Result<List<WorkflowSummary>>> listWorkflows();

  /// Fetches a single workflow and its validation status by [id]
  /// (`GET /api/v1/workflows/:id`).
  Future<Result<WorkflowResponse>> getWorkflow(String id);

  /// Creates a new workflow (`POST /api/v1/workflows`).
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  );

  /// Updates an existing workflow (`PUT /api/v1/workflows/:id`).
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request,
  );

  /// Duplicates an existing workflow (`POST /api/v1/workflows/:id/duplicate`).
  Future<Result<WorkflowResponse>> duplicateWorkflow(String id, {String? name});

  /// Deletes a workflow (`DELETE /api/v1/workflows/:id`).
  Future<Result<void>> deleteWorkflow(String id);

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
  Future<Result<List<WorkflowSummary>>> listWorkflows() async {
    final result = await _client.sendJsonRequest('GET', _basePath);
    return _decode(
      result,
      (json) => WorkflowListResponse.fromJson(json).workflows,
    );
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(String id) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'GET',
      '$_basePath/$encodedId',
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
    UpdateWorkflowRequest request,
  ) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'PUT',
      '$_basePath/$encodedId',
      body: request.toJson(),
    );
    return _decode(result, WorkflowResponse.fromJson);
  }

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
  }) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'POST',
      '$_basePath/$encodedId/duplicate',
      body: name == null ? null : DuplicateWorkflowRequest(name: name).toJson(),
    );
    return _decode(result, WorkflowResponse.fromJson);
  }

  @override
  Future<Result<void>> deleteWorkflow(String id) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'DELETE',
      '$_basePath/$encodedId',
    );
    return result.map((_) {});
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
