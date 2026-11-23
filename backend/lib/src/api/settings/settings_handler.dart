import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/settings/settings_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// HTTP handlers for `/api/v1/settings`.
final class SettingsHandler {
  /// Creates the handler backed by [_service].
  const new(this._service);

  final SettingsService _service;

  /// `GET /api/v1/settings` — returns the current effective [AppSettings].
  Future<Response> get(Request request) async {
    final result = await _service.getSettings();
    return result.fold<Response>(
      onSuccess: (settings) => jsonResponse(200, settings),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `PUT /api/v1/settings` — validates, persists, and applies settings.
  Future<Response> update(Request request) async {
    final raw = await request.readAsString();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: 'Request body must be valid JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: 'Request body must be a JSON object.',
      );
    }

    final UpdateSettingsRequest body;
    try {
      body = UpdateSettingsRequest.fromJson(decoded);
    } on FormatException catch (e) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: e.message,
      );
    }

    final result = await _service.updateSettings(body);
    return result.fold<Response>(
      onSuccess: (settings) => jsonResponse(200, settings),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }
}
