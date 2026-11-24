import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote transport contract for workflow fan-out reference lookups.
abstract interface class WorkflowReferencesRemoteDataSource {
  /// Fetches workflows referencing [workflowId] via the backend REST API.
  Future<Result<WorkflowReferencesResponse>> getReferences(
    String workflowId, {
    String? workspaceId,
  });
}

/// HTTP-over-Unix-socket [WorkflowReferencesRemoteDataSource].
final class HttpWorkflowReferencesRemoteDataSource
    implements WorkflowReferencesRemoteDataSource {
  /// Creates a data source backed by [_client].
  const new(this._client);

  final BackendClient _client;

  @override
  Future<Result<WorkflowReferencesResponse>> getReferences(
    String workflowId, {
    String? workspaceId,
  }) async {
    final encoded = Uri.encodeComponent(workflowId);
    final query = workspaceId == null
        ? ''
        : '?workspaceId=${Uri.encodeQueryComponent(workspaceId)}';
    final result = await _client.sendJsonRequest(
      'GET',
      '/api/v1/workflows/$encoded/references$query',
    );
    return result.flatMap((json) {
      try {
        return Success<WorkflowReferencesResponse>(
          WorkflowReferencesResponse.fromJson(json),
        );
      } on FormatException catch (error) {
        return FailureResult<WorkflowReferencesResponse>(
          BackendFailure(
            'Invalid workflow references payload: ${error.message}',
          ),
        );
      }
    });
  }
}
