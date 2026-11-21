import 'dart:convert';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// HTTP handler for `/api/v1/pauses` routes.
final class PausesHandler {
  /// Creates a pauses handler backed by [_service].
  new({required this._service, Handler? notFound}) {
    _router = (notFound == null ? Router() : Router(notFoundHandler: notFound))
      ..get('/', _list)
      ..get('/<id>', _getById)
      ..post('/<id>/answer', _answer);
  }

  final PauseService _service;
  late final Router _router;

  /// Dispatches one request under `/api/v1/pauses`.
  Future<Response> call(Request request) => _router.call(request);

  Future<Response> _list(Request request) async {
    final params = request.url.queryParameters;

    PauseStatus? status = PauseStatus.pending;
    final rawStatus = params['status'];
    if (rawStatus != null && rawStatus.isNotEmpty) {
      if (rawStatus == 'all') {
        status = null;
      } else {
        try {
          status = PauseStatus.fromName(rawStatus);
        } on FormatException catch (e) {
          return _badRequest(request, e.message);
        }
      }
    }

    final rawRunId = params['runId'];
    final runId = (rawRunId != null && rawRunId.isNotEmpty) ? rawRunId : null;

    final limitParsed = _parseOptionalInt(request, params['limit'], 'limit');
    if (limitParsed.error != null) return limitParsed.error!;
    final offsetParsed = _parseOptionalInt(request, params['offset'], 'offset');
    if (offsetParsed.error != null) return offsetParsed.error!;

    final result = await _service.listPauses(
      status: status,
      runId: runId,
      limit: limitParsed.value ?? 50,
      offset: offsetParsed.value ?? 0,
    );
    return _mapResult(request, result, 200);
  }

  Future<Response> _getById(Request request, String id) async {
    final result = await _service.getPause(id);
    return _mapResult(request, result, 200);
  }

  Future<Response> _answer(Request request, String id) async {
    final parsed = await _readJsonBody(request, AnswerPauseRequest.fromJson);
    if (parsed.error != null) return parsed.error!;
    final result = await _service.answerPause(id, parsed.value!);
    return _mapResult(request, result, 200);
  }

  Response _mapResult(Request request, Result<Object?> result, int status) =>
      switch (result) {
        Success<Object?>(:final value) => jsonResponse(status, value),
        FailureResult<Object?>(:final failure) => failureResponse(
          request,
          failure,
        ),
      };

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
        error: _badRequest(request, 'Query parameter "$name" must be an int.'),
      );
    }
    return (value: parsed, error: null);
  }

  Future<({T? value, Response? error})> _readJsonBody<T>(
    Request request,
    T Function(JsonMap) fromJson,
  ) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) {
      return (
        value: null,
        error: _badRequest(request, 'Request body must be a JSON object.'),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return (
        value: null,
        error: _badRequest(request, 'Request body is not valid JSON.'),
      );
    }
    if (decoded is! JsonMap) {
      return (
        value: null,
        error: _badRequest(request, 'Request body must be a JSON object.'),
      );
    }

    try {
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
}
