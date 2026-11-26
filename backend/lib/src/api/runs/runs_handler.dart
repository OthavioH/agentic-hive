import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// HTTP handler for `/api/v1/runs` routes.
final class RunsHandler {
  /// Creates a runs handler backed by [_service].
  new({required this._service, Handler? notFound}) {
    _router = (notFound == null ? Router() : Router(notFoundHandler: notFound))
      ..get('/', _list)
      ..post('/', _start)
      ..get('/<id>', _getById)
      ..post('/<id>/cancel', _cancel)
      ..post('/<id>/resume', _resume)
      ..get('/<id>/events', _events)
      ..get('/<id>/checkpoints', _checkpoints)
      ..get('/<id>/nodes/<nodeId>/logs', _logs)
      ..delete('/<id>', _delete);
  }

  /// Maximum request body size for `POST /api/v1/runs`: base64 of 25 MiB plus
  /// 1 MiB for the Run input (64 KiB, up to 6x JSON-escaped), names and
  /// overrides.
  static const int maxStartRunBodyBytes =
      (RunAttachmentLimits.maxTotalBytes + 2) ~/ 3 * 4 + 1024 * 1024;

  final RunService _service;
  late final Router _router;

  /// Dispatches one request under `/api/v1/runs`.
  Future<Response> call(Request request) => _router.call(request);

  Future<Response> _list(Request request) async {
    final params = request.url.queryParameters;

    RunStatus? status;
    final rawStatus = params['status'];
    if (rawStatus != null && rawStatus.isNotEmpty) {
      try {
        status = RunStatus.fromName(rawStatus);
      } on FormatException catch (e) {
        return _badRequest(request, e.message);
      }
    }

    final rawWorkflowId = params['workflowId'];
    final workflowId = (rawWorkflowId != null && rawWorkflowId.isNotEmpty)
        ? rawWorkflowId
        : null;

    final rawWorkspaceId = params['workspaceId'];
    final workspaceId = (rawWorkspaceId != null && rawWorkspaceId.isNotEmpty)
        ? rawWorkspaceId
        : null;

    final limitParsed = _parseOptionalInt(request, params['limit'], 'limit');
    if (limitParsed.error != null) return limitParsed.error!;
    final offsetParsed = _parseOptionalInt(request, params['offset'], 'offset');
    if (offsetParsed.error != null) return offsetParsed.error!;

    final result = await _service.listRuns(
      status: status,
      workflowId: workflowId,
      workspaceId: workspaceId,
      limit: limitParsed.value ?? 50,
      offset: offsetParsed.value ?? 0,
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _start(Request request) async {
    final parsed = await _readJsonBody(
      request,
      StartRunRequest.fromJson,
      maxBytes: maxStartRunBodyBytes,
    );
    if (parsed.error != null) return parsed.error!;
    final result = await _service.startRun(parsed.value!);
    return _mapResult(request, result, 201);
  }

  Future<Response> _getById(Request request, String id) async {
    final result = await _service.getRun(id);
    return _mapResult(request, result, 200);
  }

  Future<Response> _cancel(Request request, String id) async {
    final result = await _service.cancelRun(id);
    return _mapResult(request, result, 200);
  }

  Future<Response> _resume(Request request, String id) async {
    final result = await _service.resumeRun(id);
    return _mapResult(request, result, 200);
  }

  Future<Response> _logs(Request request, String id, String nodeId) async {
    final params = request.url.queryParameters;
    final attemptParsed = _parseOptionalInt(
      request,
      params['attempt'],
      'attempt',
    );
    if (attemptParsed.error != null) return attemptParsed.error!;

    final tailParsed = _parseOptionalInt(request, params['tail'], 'tail');
    if (tailParsed.error != null) return tailParsed.error!;

    final result = await _service.getNodeLogs(
      runId: id,
      nodeId: nodeId,
      attempt: attemptParsed.value,
      tail: tailParsed.value,
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _events(Request request, String id) async {
    final params = request.url.queryParameters;

    final afterParsed = _parseOptionalInt(
      request,
      params['afterSequence'],
      'afterSequence',
    );
    if (afterParsed.error != null) return afterParsed.error!;

    final limitParsed = _parseOptionalInt(request, params['limit'], 'limit');
    if (limitParsed.error != null) return limitParsed.error!;

    final result = await _service.getRunEvents(
      id,
      afterSequence: afterParsed.value,
      limit: limitParsed.value,
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _checkpoints(Request request, String id) async {
    final rawLatest = request.url.queryParameters['latest'];
    var latest = false;
    if (rawLatest != null && rawLatest.isNotEmpty) {
      if (rawLatest == 'true') {
        latest = true;
      } else if (rawLatest == 'false') {
        latest = false;
      } else {
        return _badRequest(
          request,
          'Query parameter "latest" must be "true" or "false".',
        );
      }
    }

    final result = await _service.getRunCheckpoints(id, latest: latest);
    return _mapResult(request, result, 200);
  }

  Future<Response> _delete(Request request, String id) async {
    final result = await _service.deleteRun(id);
    return switch (result) {
      Success<void>() => Response(204),
      FailureResult<void>(:final failure) => failureResponse(request, failure),
    };
  }

  ({int? value, Response? error}) _parseOptionalInt(
    Request request,
    String? raw,
    String name,
  ) {
    if (raw == null || raw.isEmpty) return (value: null, error: null);
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      return (
        value: null,
        error: _badRequest(
          request,
          'Query parameter "$name" must be an integer.',
        ),
      );
    }
    return (value: parsed, error: null);
  }

  Future<({T? value, Response? error})> _readJsonBody<T>(
    Request request,
    T Function(JsonMap json) fromJson, {
    int? maxBytes,
  }) async {
    final String body;
    if (maxBytes == null) {
      body = await request.readAsString();
    } else {
      final contentLength = request.contentLength;
      if (contentLength != null && contentLength > maxBytes) {
        return (
          value: null,
          error: _badRequest(request, 'Request body exceeds $maxBytes bytes.'),
        );
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in request.read()) {
        if (builder.length + chunk.length > maxBytes) {
          return (
            value: null,
            error: _badRequest(
              request,
              'Request body exceeds $maxBytes bytes.',
            ),
          );
        }
        builder.add(chunk);
      }
      try {
        body = utf8.decode(builder.takeBytes());
      } on FormatException catch (e) {
        return (value: null, error: _badRequest(request, e.message));
      }
    }
    if (body.trim().isEmpty) {
      return (
        value: null,
        error: _badRequest(request, 'Request body is empty.'),
      );
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is! JsonMap) {
        return (
          value: null,
          error: _badRequest(request, 'Request body must be a JSON object.'),
        );
      }
      return (value: fromJson(decoded), error: null);
    } on FormatException catch (e) {
      return (value: null, error: _badRequest(request, e.message));
    }
  }

  Response _badRequest(Request request, String message) => errorResponse(
    request,
    400,
    code: ApiErrorCode.badRequest,
    message: message,
  );

  Response _mapResult<T>(Request request, Result<T> result, int okStatus) =>
      switch (result) {
        Success<T>(:final value) => jsonResponse(okStatus, value),
        FailureResult<T>(:final failure) => failureResponse(request, failure),
      };
}
