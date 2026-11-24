import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool_registry.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// HTTP handler for `POST /api/v1/internal/mcp/tools/<name>`.
final class McpToolsHandler {
  /// Creates an [McpToolsHandler].
  const new({required this._registry});

  final McpToolRegistry _registry;

  /// Dispatches one MCP tool call to the registered [McpTool].
  Future<Response> call(Request request, String name) async {
    final tool = _registry.byName(name);
    if (tool == null) {
      return failureResponse(request, NotFoundFailure('Unknown tool "$name".'));
    }

    final raw = await request.readAsString();
    final Map<String, Object?> json;
    if (raw.trim().isEmpty) {
      json = const <String, Object?>{};
    } else {
      final Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException catch (e) {
        return errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'Invalid JSON: ${e.message}',
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
      json = decoded;
    }

    final McpToolCallRequest req;
    try {
      req = McpToolCallRequest.fromJson(json);
    } on FormatException catch (e) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: e.message,
      );
    }

    final result = await tool.call(
      McpToolInput(arguments: req.arguments, cwd: req.cwd),
    );
    return switch (result) {
      Success(:final value) => jsonResponse(
        200,
        McpToolCallResponse(text: value),
      ),
      FailureResult(:final failure) => failureResponse(request, failure),
    };
  }
}
