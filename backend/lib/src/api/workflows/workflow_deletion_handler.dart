import 'package:agentic_hive_backend/src/api/workflows/workflow_deletion_mapper.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:shelf/shelf.dart';

/// HTTP handler for workflow deletion status.
final class WorkflowDeletionHandler {
  /// Creates the handler backed by the workflow service.
  const new({required this._service});

  final WorkflowService _service;

  /// Answers the status for [operationId].
  Future<Response> getById(Request request, String operationId) async =>
      switch (_service.getDeletion(operationId)) {
        Success(:final value) => jsonResponse(
          200,
          workflowDeletionStatusOf(value),
        ),
        FailureResult(:final failure) => failureResponse(request, failure),
      };
}
