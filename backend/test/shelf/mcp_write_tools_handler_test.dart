import 'dart:convert';

import 'package:agentic_hive_backend/src/api/mcp_tools/mcp_tools_handler.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool_registry.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/create_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/duplicate_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_create_input.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../unit/mcp_tools/support/fakes.dart';
import 'support.dart';

final class _Events implements WorkflowEvents {
  const new();

  @override
  void workflowChanged(
    WorkflowChangeKind kind,
    String id, {
    String? workspaceId,
    WorkflowSummary? workflow,
  }) {}
}

void main() {
  late McpToolsHandler handler;
  setUp(() {
    final global = MemoryWorkflows();
    final workspaces = MemoryWorkspaces();
    final service = WorkflowService(
      repository: global,
      validator: const WorkflowValidator(),
      workspaceWorkflows: MemoryWorkspaceWorkflows(),
      workspaces: workspaces,
    );
    final scopes = McpScopeResolver(
      workspaces: workspaces,
      worktreesDir: '/tmp/worktrees',
      path: p.posix,
    );
    const formatter = WorkflowTextFormatter();
    const parser = WorkflowCreateInputParser(describe: NodeDescriptors.of);
    const events = _Events();
    handler = McpToolsHandler(
      registry: McpToolRegistry([
        CreateWorkflowTool(
          scopes: scopes,
          workflows: service,
          parser: parser,
          formatter: formatter,
          events: events,
        ),
        DuplicateWorkflowTool(
          scopes: scopes,
          workflows: service,
          formatter: formatter,
          events: events,
        ),
      ]),
    );
  });

  test('create_workflow through the route answers 200 text', () async {
    final res = await handler.call(
      buildRequest(
        '/tools/create_workflow',
        method: 'POST',
        body: jsonEncode({
          'arguments': {
            'name': 'Review',
            'nodes': [
              {'id': 'plan', 'type': 'custom', 'label': 'Plan'},
            ],
            'edges': <Object?>[],
            'entryNodeId': 'plan',
          },
        }),
      ),
      'create_workflow',
    );
    expect(res.statusCode, 200);
    expect((await readJson(res))['text'], contains('Created workflow '));
  });

  test('a rejected create answers 400 with the message', () async {
    final res = await handler.call(
      buildRequest(
        '/tools/create_workflow',
        method: 'POST',
        body: jsonEncode({
          'arguments': {
            'name': 'Bad',
            'nodes': [
              {'id': 'bad-id', 'type': 'custom', 'label': 'Bad'},
            ],
            'edges': <Object?>[],
            'entryNodeId': 'bad-id',
          },
        }),
      ),
      'create_workflow',
    );
    expect(res.statusCode, 400);
    expect(
      (await readJson(res))['error'],
      containsPair('message', contains('bad-id')),
    );
  });

  test('duplicate of an unknown id answers 404', () async {
    final res = await handler.call(
      buildRequest(
        '/tools/duplicate_workflow',
        method: 'POST',
        body: jsonEncode({
          'arguments': {'id': 'missing'},
        }),
      ),
      'duplicate_workflow',
    );
    expect(res.statusCode, 404);
    expect(
      (await readJson(res))['error'],
      containsPair('message', contains('Global scope')),
    );
  });
}
