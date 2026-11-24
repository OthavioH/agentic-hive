import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp_tool_call.freezed.dart';
part 'mcp_tool_call.g.dart';

/// Request body for `POST /api/v1/internal/mcp/tools/<name>`.
@freezed
sealed class McpToolCallRequest with _$McpToolCallRequest {
  /// Creates an MCP tool call request.
  const factory({
    @Default(<String, Object?>{}) JsonMap arguments,
    String? cwd,
  }) = _McpToolCallRequest;

  /// Decodes an MCP tool call request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$McpToolCallRequestFromJson);
}

/// Response body for `POST /api/v1/internal/mcp/tools/<name>`.
@freezed
sealed class McpToolCallResponse with _$McpToolCallResponse {
  /// Creates an MCP tool call response.
  const factory({required String text}) = _McpToolCallResponse;

  /// Decodes an MCP tool call response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$McpToolCallResponseFromJson);
}
