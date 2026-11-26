import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/mcp/hive_mcp_backend_client.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_tool_catalog.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_tools_client.dart';
import 'package:dart_mcp/server.dart';

/// Stateless stdio MCP server exposing `report_result` and `ask_human`
/// (ADR 0003, ADR 0015).
final class HiveMcpServer extends MCPServer with ToolsSupport {
  /// Creates the MCP server over [channel] forwarding tool calls to [client].
  new(
    super.channel, {
    required this.client,
    required this.tools,
    super.protocolLogSink,
  }) : super.fromStreamChannel(
         implementation: Implementation(name: 'hive-mcp', version: '0.2.0'),
         instructions:
             'Manage Agentic Hive workflows only through these tools, never by '
             'editing workspace workflow files. Workflow tools take an '
             'optional workspace (id, root path or "global"); report_result '
             'and ask_human work only inside a run.',
       );

  /// Unix-socket client forwarding tool calls to the local backend, or `null`
  /// when running outside an active Agentic Hive run.
  final HiveMcpBackendClient? client;

  /// Forwards the backend-served workflow tools (ADR 0026).
  final HiveMcpToolForwarder tools;

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) {
    registerTool(
      Tool(
        name: 'report_result',
        description:
            'Report the final structured outcome of this workflow node.',
        inputSchema: ObjectSchema(
          properties: <String, Schema>{
            'status': StringSchema(
              description:
                  'Outcome status matching one of the node available outputs.',
            ),
            'summary': StringSchema(
              description: 'Non-blank human-readable summary of what was done.',
            ),
            'data': ObjectSchema(
              description:
                  'Optional structured JSON object for downstream nodes.',
              additionalProperties: true,
            ),
            'artifacts': ListSchema(
              description:
                  'Optional list of workspace-relative artifact file paths.',
              items: StringSchema(),
            ),
          },
          required: const <String>['status', 'summary'],
          additionalProperties: false,
        ),
      ),
      _handleReportResult,
    );

    registerTool(
      Tool(
        name: 'ask_human',
        description:
            'Pause execution and ask the human user a question, blocking '
            'until the user answers or the run is cancelled.',
        inputSchema: ObjectSchema(
          properties: <String, Schema>{
            'question': StringSchema(
              description: 'Non-blank question to present to the user.',
            ),
            'options': ListSchema(
              description: 'Optional list of suggested answer choices.',
              items: StringSchema(),
            ),
          },
          required: const <String>['question'],
          additionalProperties: false,
        ),
      ),
      _handleAskHuman,
    );

    for (final tool in HiveMcpToolCatalog.backendTools) {
      registerTool(tool, (request) => _forward(tool.name, request));
    }

    return super.initialize(request);
  }

  Future<CallToolResult> _forward(String name, CallToolRequest request) async {
    final result = await tools.callTool(
      name,
      request.arguments ?? const <String, Object?>{},
    );
    return CallToolResult(
      isError: result.isError ? true : null,
      content: <Content>[TextContent(text: result.message)],
    );
  }

  static const _outsideRunMessage =
      'Not running inside an Agentic Hive run (missing HIVE_SOCKET_PATH, '
      'HIVE_RUN_ID, HIVE_NODE_ID, or HIVE_ATTEMPT).';

  Future<CallToolResult> _handleReportResult(CallToolRequest request) async {
    final activeClient = client;
    if (activeClient == null) {
      return CallToolResult(
        isError: true,
        content: <Content>[TextContent(text: _outsideRunMessage)],
      );
    }
    final result = await activeClient.reportResult(
      request.arguments ?? const <String, Object?>{},
    );
    if (result.isError) {
      return CallToolResult(
        isError: true,
        content: <Content>[TextContent(text: result.message)],
      );
    }
    return CallToolResult(
      content: <Content>[TextContent(text: result.message)],
    );
  }

  Future<CallToolResult> _handleAskHuman(CallToolRequest request) async {
    final activeClient = client;
    if (activeClient == null) {
      return CallToolResult(
        isError: true,
        content: <Content>[TextContent(text: _outsideRunMessage)],
      );
    }
    final result = await activeClient.askHuman(
      request.arguments ?? const <String, Object?>{},
    );
    if (result.isError) {
      return CallToolResult(
        isError: true,
        content: <Content>[TextContent(text: result.message)],
      );
    }

    var text = result.message;
    try {
      final decoded = jsonDecode(result.message);
      if (decoded is Map<String, Object?> && decoded['answer'] is String) {
        text = decoded['answer']! as String;
      }
    } on FormatException {
      // Keep raw response text if non-JSON.
    }

    return CallToolResult(content: <Content>[TextContent(text: text)]);
  }
}
