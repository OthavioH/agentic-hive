import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/api/mcp_tools/mcp_tools_handler.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool_registry.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/delete_workflow_tool.dart';
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
    DefinitionScope scope = const GlobalScope(),
    WorkflowSummary? workflow,
  }) {}
}

void main() {
  late GatedRunsDeleter deleter;
  late McpToolsHandler handler;
  late WorkflowResponse seeded;

  setUp(() async {
    deleter = GatedRunsDeleter();
    final service = WorkflowService(
      repository: MemoryWorkflows(),
      validator: const WorkflowValidator(),
      runsDeleter: deleter,
    );
    final scope = McpScopeResolver(
      workspaces: MemoryWorkspaces(),
      worktreesDir: '/tmp/worktrees',
      path: p.posix,
    );
    handler = McpToolsHandler(
      registry: McpToolRegistry([
        DeleteWorkflowTool(
          scopes: scope,
          workflows: service,
          events: const _Events(),
          maxWait: const Duration(milliseconds: 200),
          pollInterval: const Duration(milliseconds: 10),
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

  tearDown(() async {
    final gate = deleter.gate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
    await pumpEventQueue();
  });

  Future<Response> request(Map<String, Object?> args) => handler.call(
    buildRequest(
      '/tools/delete_workflow',
      method: 'POST',
      body: jsonEncode({'arguments': args}),
    ),
    'delete_workflow',
  );

  test('delete_workflow through the route answers 200 text', () async {
    final res = await request({
      'id': seeded.workflow.id,
      'revision': seeded.revision,
    });

    expect(res.statusCode, 200);
    expect(
      (await readJson(res))['text'],
      contains('Deleted workflow "${seeded.workflow.id}" and 0 runs'),
    );
  });

  test(
    'active runs answer 409 workflow_has_active_runs listing them',
    () async {
      deleter.activeRuns = {'r1': RunStatus.running};

      final res = await request({
        'id': seeded.workflow.id,
        'revision': seeded.revision,
      });

      expect(res.statusCode, 409);
      final error = (await readJson(res))['error'];
      expect(error, containsPair('code', 'workflow_has_active_runs'));
      expect(error, containsPair('details', {'r1': 'running'}));
      expect(
        error,
        containsPair(
          'message',
          contains('Ask the user to stop them in Agentic Hive'),
        ),
      );
    },
  );

  test(
    'a stale revision answers 409 revision_conflict with currentRevision',
    () async {
      final res = await request({
        'id': seeded.workflow.id,
        'revision': 'stale',
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
      expect(
        error,
        containsPair('message', contains('Call get_workflow to read it again')),
      );
    },
  );

  test('a slow deletion answers 200 deletion in progress', () async {
    deleter.gate = Completer<void>();

    final res = await request({
      'id': seeded.workflow.id,
      'revision': seeded.revision,
    });

    expect(res.statusCode, 200);
    expect(
      (await readJson(res))['text'],
      contains('deletion in progress (operation '),
    );
  });
}
