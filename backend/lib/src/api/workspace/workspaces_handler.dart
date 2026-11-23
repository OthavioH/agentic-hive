import 'dart:convert';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// HTTP handler for the `/api/v1/workspaces` routes (ADR 0022).
final class WorkspacesHandler {
  /// Creates a handler backed by [_service].
  ///
  /// `onChanged` runs after a workspace is registered or unregistered, so
  /// per-workspace file watchers can follow the registry.
  new({required this._service, this._onChanged, Handler? notFound}) {
    _router = (notFound == null ? Router() : Router(notFoundHandler: notFound))
      ..get('/', _list)
      ..post('/', _create)
      ..get('/<id>', _getById)
      ..patch('/<id>', _rename)
      ..delete('/<id>', _delete);
  }

  final WorkspaceService _service;
  final Future<void> Function()? _onChanged;
  late final Router _router;

  /// Dispatches one request under `/api/v1/workspaces`.
  Future<Response> call(Request request) => _router.call(request);

  Future<Response> _list(Request request) async {
    final result = await _service.list();
    return switch (result) {
      Success<List<Workspace>>(:final value) => jsonResponse(
        200,
        WorkspaceListResponse(items: value),
      ),
      FailureResult<List<Workspace>>(:final failure) => failureResponse(
        request,
        failure,
      ),
    };
  }

  Future<Response> _create(Request request) async {
    final parsed = await _readBody(request, CreateWorkspaceRequest.fromJson);
    if (parsed.error != null) return parsed.error!;
    final result = await _service.create(parsed.value!);
    if (result is Success<Workspace>) await _onChanged?.call();
    return _mapResult(request, result, 201);
  }

  Future<Response> _getById(Request request, String id) async =>
      _mapResult(request, await _service.get(id), 200);

  Future<Response> _rename(Request request, String id) async {
    final parsed = await _readBody(request, UpdateWorkspaceRequest.fromJson);
    if (parsed.error != null) return parsed.error!;
    return _mapResult(request, await _service.rename(id, parsed.value!), 200);
  }

  Future<Response> _delete(Request request, String id) async {
    final result = await _service.unregister(id);
    if (result is Success<void>) await _onChanged?.call();
    return switch (result) {
      Success<void>() => jsonResponse(200, {'id': id, 'deleted': true}),
      FailureResult<void>(:final failure) => failureResponse(request, failure),
    };
  }

  Response _mapResult<T>(Request request, Result<T> result, int okStatus) =>
      switch (result) {
        Success<T>(:final value) => jsonResponse(okStatus, value),
        FailureResult<T>(:final failure) => failureResponse(request, failure),
      };

  Future<({T? value, Response? error})> _readBody<T>(
    Request request,
    T Function(JsonMap) fromJson,
  ) async {
    final raw = await request.readAsString();
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
