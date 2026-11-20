import 'dart:convert';

import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// A response with a JSON [body].
Response jsonResponse(int statusCode, Object? body) =>
    Response(statusCode, body: jsonEncode(body), headers: _jsonHeaders);

/// A response with the standard [ApiError] body, tagged with the request id.
Response errorResponse(
  Request request,
  int statusCode, {
  required String code,
  required String message,
}) => jsonResponse(
  statusCode,
  ApiError(code: code, message: message, requestId: requestIdOf(request)),
);
