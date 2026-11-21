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
      ..get('/<id>', _getById)
      ..get('/<id>/events', _events)
      ..get('/<id>/checkpoints', _checkpoints)
      ..delete('/<id>', _delete);
  }

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

    final limitParsed = _parseOptionalInt(request, params['limit'], 'limit');
    if (limitParsed.error != null) return limitParsed.error!;
    final offsetParsed = _parseOptionalInt(request, params['offset'], 'offset');
    if (offsetParsed.error != null) return offsetParsed.error!;

    final result = await _service.listRuns(
      status: status,
      workflowId: workflowId,
      limit: limitParsed.value ?? 50,
      offset: offsetParsed.value ?? 0,
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _getById(Request request, String id) async {
    final result = await _service.getRun(id);
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
