import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/mcp/hive_mcp_backend_client.dart';
import 'package:dart_mcp/server.dart';

/// Stateless stdio MCP server exposing `report_result` and `ask_human`
/// (ADR 0003, ADR 0015).
final class HiveMcpServer extends MCPServer with ToolsSupport {
  /// Creates the MCP server over [channel] forwarding tool calls to [client].
  new(super.channel, {required this.client, super.protocolLogSink})
    : super.fromStreamChannel(
        implementation: Implementation(name: 'hive-mcp', version: '0.1.0'),
        instructions:
            'Use report_result to submit your final node outcome and '
            'ask_human when you need clarification from the user.',
      );

  /// Unix-socket client forwarding tool calls to the local backend, or `null`
  /// when running outside an active Agentic Hive run.
  final HiveMcpBackendClient? client;

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

    return super.initialize(request);
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
