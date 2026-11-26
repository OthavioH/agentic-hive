import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/agents/agent_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// HTTP handlers for `/api/v1/agents`.
final class AgentsHandler {
  /// Creates the handler backed by [_service].
  const new(this._service);

  final AgentService _service;

  /// The `workspaceId` query parameter, mapped to [DefinitionScope].
  DefinitionScope _scope(Request request) {
    final value = request.url.queryParameters['workspaceId']?.trim();
    return DefinitionScope.ofWorkspaceId(
      value == null || value.isEmpty ? null : value,
    );
  }

  /// `GET /api/v1/agents` — lists the global agents, or with `?workspaceId=`
  /// the workspace agents plus the global ones (ADR 0025).
  Future<Response> list(Request request) async {
    final result = await _service.list(scope: _scope(request));
    return result.fold<Response>(
      onSuccess: (agents) =>
          jsonResponse(200, AgentListResponse(agents: agents)),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `GET /api/v1/agents/<id>` — returns the full agent detail.
  Future<Response> getById(Request request, String id) async {
    final decodedId = _decodePathId(id);
    if (decodedId == null) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: 'Invalid URL-encoded agent id.',
      );
    }
    final result = await _service.getById(decodedId, scope: _scope(request));
    return result.fold<Response>(
      onSuccess: (detail) => jsonResponse(200, detail),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `POST /api/v1/agents` — creates a new `<id>.md` file.
  Future<Response> create(Request request) async {
    final decoded = await _decodeJsonBody(request);
    if (decoded.error != null) return decoded.error!;

    final CreateAgentRequest body;
    try {
      body = CreateAgentRequest.fromJson(decoded.json!);
    } on FormatException catch (e) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: e.message,
      );
    }

    final result = await _service.create(body, scope: _scope(request));
    return result.fold<Response>(
      onSuccess: (detail) => jsonResponse(201, detail),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `PUT /api/v1/agents/<id>` — updates an existing `<id>.md` file.
  Future<Response> update(Request request, String id) async {
    final decodedId = _decodePathId(id);
    if (decodedId == null) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: 'Invalid URL-encoded agent id.',
      );
    }
    final decoded = await _decodeJsonBody(request);
    if (decoded.error != null) return decoded.error!;

    final UpdateAgentRequest body;
    try {
      body = UpdateAgentRequest.fromJson(decoded.json!);
    } on FormatException catch (e) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: e.message,
      );
    }

    final result = await _service.update(
      decodedId,
      body,
      scope: _scope(request),
    );
    return result.fold<Response>(
      onSuccess: (detail) => jsonResponse(200, detail),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `DELETE /api/v1/agents/<id>` — deletes `<id>.md`.
  Future<Response> delete(Request request, String id) async {
    final decodedId = _decodePathId(id);
    if (decodedId == null) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: 'Invalid URL-encoded agent id.',
      );
    }
    final result = await _service.delete(decodedId, scope: _scope(request));
    return result.fold<Response>(
      onSuccess: (_) => jsonResponse(200, {'id': decodedId, 'deleted': true}),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  static final _invalidPercentEscape = RegExp(
    r'%([^0-9A-Fa-f]|[0-9A-Fa-f][^0-9A-Fa-f]|.$)|%$',
  );

  String? _decodePathId(String rawId) {
    if (_invalidPercentEscape.hasMatch(rawId)) return null;
    try {
      return Uri.decodeComponent(rawId);
    } on FormatException {
      return null;
    }
  }

  Future<({JsonMap? json, Response? error})> _decodeJsonBody(
    Request request,
  ) async {
    final raw = await request.readAsString();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return (
        json: null,
        error: errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'Request body must be valid JSON.',
        ),
      );
    }
    if (decoded is! Map<String, Object?>) {
      return (
        json: null,
        error: errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'Request body must be a JSON object.',
        ),
      );
    }
    return (json: decoded, error: null);
  }
}
