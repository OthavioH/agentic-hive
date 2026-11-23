import 'dart:convert';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// HTTP handler for `/api/v1/workflows` routes.
final class WorkflowHandler {
  /// Creates a workflow handler backed by [_service].
  new({required this._service, Handler? notFound}) {
    _router = (notFound == null ? Router() : Router(notFoundHandler: notFound))
      ..get('/', _list)
      ..post('/', _create)
      ..post('/validate', _validate)
      ..get('/<id>', _getById)
      ..put('/<id>', _update)
      ..delete('/<id>', _delete)
      ..post('/<id>/duplicate', _duplicate);
  }

  final WorkflowService _service;
  late final Router _router;

  /// Dispatches one request under `/api/v1/workflows`.
  Future<Response> call(Request request) => _router.call(request);

  Future<Response> _list(Request request) async {
    final result = await _service.listWorkflows(
      workspaceId: _workspaceId(request),
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _create(Request request) async {
    final parsed = await _readJsonBody(request, CreateWorkflowRequest.fromJson);
    if (parsed.error != null) return parsed.error!;
    final result = await _service.createWorkflow(parsed.value!);
    return _mapResult(request, result, 201);
  }

  Future<Response> _validate(Request request) async {
    final parsed = await _readJsonBody(
      request,
      ValidateWorkflowRequest.fromJson,
    );
    if (parsed.error != null) return parsed.error!;
    final validation = _service.validateWorkflow(parsed.value!.workflow);
    return jsonResponse(200, validation);
  }

  Future<Response> _getById(Request request, String id) async {
    final result = await _service.getWorkflow(
      id,
      workspaceId: _workspaceId(request),
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _update(Request request, String id) async {
    final parsed = await _readJsonBody(request, UpdateWorkflowRequest.fromJson);
    if (parsed.error != null) return parsed.error!;
    final result = await _service.updateWorkflow(
      id,
      parsed.value!,
      workspaceId: _workspaceId(request),
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _delete(Request request, String id) async {
    final raw = request.url.queryParameters['force'];
    final bool force;
    if (raw == null || raw.isEmpty || raw == 'false') {
      force = false;
    } else if (raw == 'true') {
      force = true;
    } else {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: 'Query parameter "force" must be "true" or "false".',
      );
    }
    final result = await _service.deleteWorkflow(
      id,
      workspaceId: _workspaceId(request),
      expectedRevision: _revision(request),
      force: force,
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _duplicate(Request request, String id) async {
    final raw = await request.readAsString();
    String? name;
    if (raw.trim().isNotEmpty) {
      final parsed = _decodeBody(
        raw,
        request,
        DuplicateWorkflowRequest.fromJson,
      );
      if (parsed.error != null) return parsed.error!;
      name = parsed.value!.name;
    }
    final result = await _service.duplicateWorkflow(
      id,
      name: name,
      workspaceId: _workspaceId(request),
    );
    return _mapResult(request, result, 201);
  }

  /// The `workspaceId` query parameter; absent or blank means the global scope.
  String? _workspaceId(Request request) {
    final value = request.url.queryParameters['workspaceId']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// The `revision` query parameter; absent or blank means no check.
  String? _revision(Request request) {
    final value = request.url.queryParameters['revision']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Response _mapResult<T>(Request request, Result<T> result, int okStatus) =>
      switch (result) {
        Success<T>(:final value) => jsonResponse(okStatus, value),
        FailureResult<T>(:final failure) => failureResponse(request, failure),
      };

  Future<({T? value, Response? error})> _readJsonBody<T>(
    Request request,
    T Function(JsonMap) fromJson,
  ) async {
    final raw = await request.readAsString();
    return _decodeBody(raw, request, fromJson);
  }

  ({T? value, Response? error}) _decodeBody<T>(
    String raw,
    Request request,
    T Function(JsonMap) fromJson,
  ) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return (
          value: null,
          error: errorResponse(
            request,
            400,
            code: ApiErrorCode.badRequest,
            message: 'Request body must be a JSON object.',
          ),
        );
      }
      return (value: fromJson(decoded), error: null);
    } on FormatException catch (e) {
      return (
        value: null,
        error: errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: e.message,
        ),
      );
    }
  }
}
