import 'dart:convert';

import 'package:agentic_hive_backend/src/api/mcp_tools/mcp_tools_handler.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool_registry.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/edit_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_patcher.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
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
  late WorkflowResponse seeded;

  setUp(() async {
    final global = MemoryWorkflows();
    final workspaces = MemoryWorkspaces();
    final service = WorkflowService(
      repository: global,
      validator: const WorkflowValidator(),
    );
    final scope = McpScopeResolver(
      workspaces: workspaces,
      worktreesDir: '/tmp/worktrees',
      path: p.posix,
    );
    const formatter = WorkflowTextFormatter();
    handler = McpToolsHandler(
      registry: McpToolRegistry([
        EditWorkflowTool(
          scopes: scope,
          workflows: service,
          patcher: WorkflowPatcher(describe: NodeDescriptors.of),
          formatter: formatter,
          events: const _Events(),
        ),
      ]),
    );
    final created = await service.createWorkflow(
      const CreateWorkflowRequest(
        name: 'Review',
        nodes: [
          WorkflowNode(
            id: 'n',
            type: 'custom',
            label: 'Node',
            position: WorkflowPosition(x: 1, y: 1),
          ),
        ],
        entryNodeId: 'n',
      ),
    );
    seeded = (created as Success<WorkflowResponse>).value;
  });

  Future<Response> request(Map<String, Object?> args) => handler.call(
    buildRequest(
      '/tools/edit_workflow',
      method: 'POST',
      body: jsonEncode({'arguments': args}),
    ),
    'edit_workflow',
  );

  test('edit_workflow through the route answers 200 text', () async {
    final res = await request({
      'id': seeded.workflow.id,
      'revision': seeded.revision,
      'operations': [
        {'op': 'update_node', 'id': 'n', 'label': 'Changed'},
      ],
    });
    expect(res.statusCode, 200);
    expect((await readJson(res))['text'], contains('Edited workflow'));
  });

  test('an invalid operation answers 400 with the message', () async {
    final res = await request({
      'id': seeded.workflow.id,
      'revision': seeded.revision,
      'operations': [
        {'op': 'connect', 'from': 'n', 'to': 'ghost', 'output': 'x'},
      ],
    });
    expect(res.statusCode, 400);
    expect(
      (await readJson(res))['error'],
      containsPair('message', contains('operations[0] connect')),
    );
  });

  test(
    'a stale revision answers 409 revision_conflict with currentRevision',
    () async {
      final res = await request({
        'id': seeded.workflow.id,
        'revision': 'stale',
        'operations': [
          {'op': 'set_meta', 'name': 'x'},
        ],
      });
      expect(res.statusCode, 409);
      final error = (await readJson(res))['error'];
      expect(error, containsPair('code', 'revision_conflict'));
      expect(
        error,
        containsPair(
          'details',
          containsPair('currentRevision', seeded.revision),
        ),
      );
    },
  );

  test('an unknown workflow answers 404', () async {
    final res = await request({
      'id': 'missing',
      'revision': 'x',
      'operations': [
        {'op': 'set_meta', 'name': 'x'},
      ],
    });
    expect(res.statusCode, 404);
  });
}
