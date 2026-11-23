import 'dart:convert';

import 'package:agentic_hive_backend/src/api/mcp_tools/mcp_tools_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool_registry.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _EchoTool extends McpTool {
  const new();

  @override
  String get name => 'echo';

  @override
  Future<Result<String>> call(McpToolInput input) async {
    final msg = input.arguments['msg'];
    if (msg == 'missing_ws') {
      return const FailureResult(
        NotFoundFailure(
          'Unknown workspace "x": pass the workspace root path or id '
          '(see list_workspaces).',
        ),
      );
    }
    return Success('ok:${msg ?? 'none'}:${input.cwd ?? 'nocwd'}');
  }
}

void main() {
  late McpToolsHandler handler;

  setUp(() {
    handler = McpToolsHandler(registry: McpToolRegistry([const _EchoTool()]));
  });

  test('200 with text for a known tool', () async {
    final res = await handler.call(
      buildRequest(
        '/api/v1/internal/mcp/tools/echo',
        method: 'POST',
        body: jsonEncode(<String, Object?>{
          'arguments': <String, Object?>{'msg': 'hi'},
          'cwd': '/tmp',
        }),
      ),
      'echo',
    );
    expect(res.statusCode, 200);
    final json = await readJson(res);
    expect(json['text'], 'ok:hi:/tmp');
  });

  test('empty body means no arguments', () async {
    final res = await handler.call(
      buildRequest('/api/v1/internal/mcp/tools/echo', method: 'POST'),
      'echo',
    );
    expect(res.statusCode, 200);
    final json = await readJson(res);
    expect(json['text'], 'ok:none:nocwd');
  });

  test('unknown tool is 404 not_found', () async {
    final res = await handler.call(
      buildRequest('/api/v1/internal/mcp/tools/nope', method: 'POST'),
      'nope',
    );
    expect(res.statusCode, 404);
    final json = await readJson(res);
    final error = json['error']! as Map<String, Object?>;
    expect(error['code'], 'not_found');
    expect(error['message'], 'Unknown tool "nope".');
  });

  test('non-object body is 400', () async {
    final res = await handler.call(
      buildRequest(
        '/api/v1/internal/mcp/tools/echo',
        method: 'POST',
        body: '["not-an-object"]',
      ),
      'echo',
    );
    expect(res.statusCode, 400);
    final json = await readJson(res);
    final error = json['error']! as Map<String, Object?>;
    expect(error['code'], 'bad_request');
  });

  test('unknown workspace is 404 with the next-step message', () async {
    final res = await handler.call(
      buildRequest(
        '/api/v1/internal/mcp/tools/echo',
        method: 'POST',
        body: jsonEncode(<String, Object?>{
          'arguments': <String, Object?>{'msg': 'missing_ws'},
        }),
      ),
      'echo',
    );
    expect(res.statusCode, 404);
    final json = await readJson(res);
    final error = json['error']! as Map<String, Object?>;
    expect(error['code'], 'not_found');
    expect(
      error['message'],
      'Unknown workspace "x": pass the workspace root path or id '
      '(see list_workspaces).',
    );
  });

  test('route is mounted under /api/v1/internal/mcp/tools', () async {
    final api = buildApiHandler(
      statusHandler: StatusHandler(
        startedAt: DateTime.utc(2026),
        version: '0.0.0-test',
        dataDir: '/tmp',
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 1),
        ),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response.notFound('ws'),
      mcpToolsHandler: handler,
    );
    final res = await api(
      buildRequest(
        '/api/v1/internal/mcp/tools/echo',
        method: 'POST',
        body: jsonEncode(<String, Object?>{
          'arguments': <String, Object?>{'msg': 'mounted'},
        }),
      ),
    );
    expect(res.statusCode, 200);
    final json = await readJson(res);
    expect(json['text'], 'ok:mounted:nocwd');
  });
}
