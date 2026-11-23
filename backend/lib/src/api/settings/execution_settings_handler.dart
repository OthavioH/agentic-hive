import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/settings/execution_settings_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// HTTP handlers for the execution settings: the global ones at
/// `/api/v1/settings/execution` and the per-workspace overrides at
/// `/api/v1/workspaces/{id}/settings` (ADR 0025).
final class ExecutionSettingsHandler {
  /// Creates the handler backed by [_service].
  const new(this._service);

  final ExecutionSettingsService _service;

  /// `GET /api/v1/settings/execution`: the stored global settings.
  Future<Response> getGlobal(Request request) async {
    final result = await _service.getGlobal();
    return result.fold<Response>(
      onSuccess: (settings) => jsonResponse(200, settings),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `PUT /api/v1/settings/execution`: replaces the global settings.
  Future<Response> putGlobal(Request request) async {
    final parsed = await _readSettings(request);
    if (parsed.error != null) return parsed.error!;
    final result = await _service.updateGlobal(parsed.value!);
    return result.fold<Response>(
      onSuccess: (settings) => jsonResponse(200, settings),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `GET /api/v1/workspaces/{id}/settings`: overrides, inherited and
  /// effective settings of a workspace.
  Future<Response> getWorkspace(Request request, String id) async {
    final result = await _service.getForWorkspace(id);
    return result.fold<Response>(
      onSuccess: (response) => jsonResponse(200, response),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `PUT /api/v1/workspaces/{id}/settings`: replaces the overrides of a
  /// workspace. Only execution settings are accepted; machine-specific keys
  /// are rejected with `400`.
  Future<Response> putWorkspace(Request request, String id) async {
    final parsed = await _readSettings(request);
    if (parsed.error != null) return parsed.error!;
    final result = await _service.updateForWorkspace(id, parsed.value!);
    return result.fold<Response>(
      onSuccess: (response) => jsonResponse(200, response),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  Future<({ExecutionSettings? value, Response? error})> _readSettings(
    Request request,
  ) async {
    Response bad(String message) => errorResponse(
      request,
      400,
      code: ApiErrorCode.badRequest,
      message: message,
    );

    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException {
      return (value: null, error: bad('Request body must be valid JSON.'));
    }
    if (decoded is! Map<String, Object?>) {
      return (value: null, error: bad('Request body must be a JSON object.'));
    }
    final unknown = decoded.keys
        .where((key) => !ExecutionSettings.overridableKeys.contains(key))
        .toList();
    if (unknown.isNotEmpty) {
      return (
        value: null,
        error: bad(
          'Not an execution setting: ${unknown.join(', ')}. Only '
          '${ExecutionSettings.overridableKeys.join(', ')} can be set here.',
        ),
      );
    }
    try {
      return (value: ExecutionSettings.fromJson(decoded), error: null);
    } on FormatException catch (error) {
      return (value: null, error: bad(error.message));
    }
  }
}
