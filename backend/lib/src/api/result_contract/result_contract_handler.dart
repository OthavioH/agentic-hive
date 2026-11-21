import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_coordinator.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// Internal HTTP handlers for `hive-mcp` tool forwarding over the Unix domain
/// socket.
final class ResultContractHandler {
  /// Creates a handler backed by a coordinator and a human pause gateway.
  const new({required this._coordinator, required this._humanPauseGateway});

  final ResultContractCoordinator _coordinator;
  final HumanPauseGateway _humanPauseGateway;

  /// `POST /api/v1/internal/runs/<runId>/nodes/<nodeId>/attempts/<attempt>/report-result`
  Future<Response> reportResult(
    Request request,
    String runId,
    String nodeId,
    String attemptRaw,
  ) async {
    final parsed = _parseAttemptContext(request, runId, nodeId, attemptRaw);
    if (parsed.error != null) return parsed.error!;
    final ctx = parsed.context!;

    final decoded = await _decodeJsonObject(request);
    if (decoded.error != null) return decoded.error!;

    final result = _coordinator.submitMcpReport(
      runId: ctx.runId,
      nodeId: ctx.nodeId,
      attempt: ctx.attempt,
      payload: decoded.json!,
    );
    return result.fold<Response>(
      onSuccess: (report) => jsonResponse(200, <String, Object?>{
        'accepted': true,
        'status': report.status.name,
      }),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `POST /api/v1/internal/runs/<runId>/nodes/<nodeId>/attempts/<attempt>/ask-human`
  Future<Response> askHuman(
    Request request,
    String runId,
    String nodeId,
    String attemptRaw,
  ) async {
    final parsed = _parseAttemptContext(request, runId, nodeId, attemptRaw);
    if (parsed.error != null) return parsed.error!;
    final ctx = parsed.context!;

    final decoded = await _decodeJsonObject(request);
    if (decoded.error != null) return decoded.error!;
    final json = decoded.json!;

    final question = json['question'];
    if (question is! String || question.trim().isEmpty) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: 'question is required and must be a non-blank string.',
      );
    }

    final rawOptions = json['options'];
    final options = <String>[];
    if (rawOptions != null) {
      if (rawOptions is! List) {
        return errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'options must be a list of strings when provided.',
        );
      }
      for (final item in rawOptions) {
        if (item is! String) {
          return errorResponse(
            request,
            400,
            code: ApiErrorCode.badRequest,
            message: 'options must contain only strings.',
          );
        }
        options.add(item);
      }
    }

    final result = await _humanPauseGateway.requestHumanAnswer(
      runId: ctx.runId,
      nodeId: ctx.nodeId,
      attempt: ctx.attempt,
      question: question,
      options: options,
    );
    return result.fold<Response>(
      onSuccess: (answer) =>
          jsonResponse(200, <String, Object?>{'answer': answer}),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  ({({String runId, String nodeId, int attempt})? context, Response? error})
  _parseAttemptContext(
    Request request,
    String runIdRaw,
    String nodeIdRaw,
    String attemptRaw,
  ) {
    final runId = _tryDecodeComponent(runIdRaw);
    final nodeId = _tryDecodeComponent(nodeIdRaw);
    if (runId == null || nodeId == null) {
      return (
        context: null,
        error: errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'Invalid URL-encoded runId or nodeId.',
        ),
      );
    }

    if (runId.trim().isEmpty || nodeId.trim().isEmpty) {
      return (
        context: null,
        error: errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'runId and nodeId must not be empty.',
        ),
      );
    }

    final attempt = int.tryParse(attemptRaw);
    if (attempt == null || attempt < 1) {
      return (
        context: null,
        error: errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'attempt must be a positive integer.',
        ),
      );
    }

    return (
      context: (runId: runId, nodeId: nodeId, attempt: attempt),
      error: null,
    );
  }

  static String? _tryDecodeComponent(String raw) {
    if (RegExp('%(?![0-9a-fA-F]{2})').hasMatch(raw)) {
      return null;
    }
    return Uri.decodeComponent(raw);
  }

  Future<({Map<String, Object?>? json, Response? error})> _decodeJsonObject(
    Request request,
  ) async {
    final body = await request.readAsString();
    if (body.trim().isEmpty) {
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

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      return (
        json: null,
        error: errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'Invalid JSON body: ${e.message}',
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
