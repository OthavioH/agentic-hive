import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source for querying and deleting runs over the backend REST API.
abstract interface class RunsRemoteDataSource {
  /// Fetches paginated runs (`GET /api/v1/runs`).
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  });

  /// Fetches a single run by [id] (`GET /api/v1/runs/:id`).
  Future<Result<Run>> getRun(String id);

  /// Fetches events for run [id] (`GET /api/v1/runs/:id/events`).
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  });

  /// Fetches checkpoints for run [id] (`GET /api/v1/runs/:id/checkpoints`).
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id);

  /// Starts a new run (`POST /api/v1/runs`).
  Future<Result<Run>> startRun(StartRunRequest request);

  /// Requests cancellation of run [id] (`POST /api/v1/runs/:id/cancel`).
  Future<Result<Run>> cancelRun(String id);

  /// Resumes an interrupted run [id] (`POST /api/v1/runs/:id/resume`).
  Future<Result<Run>> resumeRun(String id);

  /// Fetches logs for [nodeId] in run [id]
  /// (`GET /api/v1/runs/:id/nodes/:nodeId/logs`).
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  });

  /// Deletes run [id] (`DELETE /api/v1/runs/:id`).
  Future<Result<void>> deleteRun(String id);
}

/// [RunsRemoteDataSource] backed by [BackendClient].
final class HttpRunsRemoteDataSource implements RunsRemoteDataSource {
  /// Creates an HTTP runs data source using [_client].
  const new(this._client);

  static const String _basePath = '/api/v1/runs';

  final BackendClient _client;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async {
    final queryParameters = <String, String>{
      if (status != null) 'status': status.name,
      if (workflowId != null && workflowId.isNotEmpty) 'workflowId': workflowId,
      if (workspaceId != null && workspaceId.isNotEmpty)
        'workspaceId': workspaceId,
      if (limit != null) 'limit': '$limit',
      if (offset != null) 'offset': '$offset',
    };
    final path = Uri(
      path: _basePath,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
    final result = await _client.sendJsonRequest('GET', path);
    return _decode(result, RunsListResponse.fromJson);
  }

  @override
  Future<Result<Run>> getRun(String id) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'GET',
      '$_basePath/$encodedId',
    );
    return _decode(result, Run.fromJson);
  }

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async {
    final encodedId = Uri.encodeComponent(id);
    final queryParameters = <String, String>{
      if (afterSequence != null) 'afterSequence': '$afterSequence',
      if (limit != null) 'limit': '$limit',
    };
    final path = Uri(
      path: '$_basePath/$encodedId/events',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
    final result = await _client.sendJsonRequest('GET', path);
    return _decode(result, RunEventsResponse.fromJson);
  }

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'GET',
      '$_basePath/$encodedId/checkpoints',
    );
    return _decode(
      result,
      (json) => RunCheckpointsResponse.fromJson(json).items,
    );
  }

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async {
    final result = await _client.sendJsonRequest(
      'POST',
      _basePath,
      body: request.toJson(),
    );
    return _decode(result, Run.fromJson);
  }

  @override
  Future<Result<Run>> cancelRun(String id) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'POST',
      '$_basePath/$encodedId/cancel',
    );
    return _decode(result, Run.fromJson);
  }

  @override
  Future<Result<Run>> resumeRun(String id) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'POST',
      '$_basePath/$encodedId/resume',
    );
    return _decode(result, Run.fromJson);
  }

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async {
    final encodedId = Uri.encodeComponent(id);
    final encodedNodeId = Uri.encodeComponent(nodeId);
    final queryParameters = <String, String>{
      if (attempt != null) 'attempt': '$attempt',
      if (tail != null) 'tail': '$tail',
    };
    final path = Uri(
      path: '$_basePath/$encodedId/nodes/$encodedNodeId/logs',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
    final result = await _client.sendJsonRequest('GET', path);
    return _decode(result, RunNodeLogsResponse.fromJson);
  }

  @override
  Future<Result<void>> deleteRun(String id) async {
    final encodedId = Uri.encodeComponent(id);
    final result = await _client.sendJsonRequest(
      'DELETE',
      '$_basePath/$encodedId',
    );
    return result.map((_) {});
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
          BackendFailure('Invalid run payload: ${error.message}'),
        );
      }
    });
  }
}
