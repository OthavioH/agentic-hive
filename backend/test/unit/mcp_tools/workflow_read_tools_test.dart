import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/get_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/list_workflows_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/list_workspaces_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fakes.dart';

Workflow _wf(String id, String name) => Workflow(
  id: id,
  name: name,
  entryNodeId: 'n1',
  nodes: const <WorkflowNode>[
    WorkflowNode(
      id: 'n1',
      type: 'harness.claude_code',
      label: 'N1',
      position: WorkflowPosition(x: 0, y: 0),
    ),
  ],
  edges: const <WorkflowEdge>[],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late MemoryWorkflows globalRepo;
  late MemoryWorkspaceWorkflows wsWfRepo;
  late MemoryWorkspaces workspaces;
  late WorkflowService service;
  late McpScopeResolver scopes;
  const formatter = WorkflowTextFormatter();

  final ws1 = Workspace(
    id: 'ws-1',
    name: 'App',
    rootPath: r'C:\repos\app',
    isGit: true,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final ws2 = Workspace(
    id: 'ws-2',
    name: 'Lib',
    rootPath: r'C:\repos\lib',
    isGit: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() async {
    globalRepo = MemoryWorkflows();
    wsWfRepo = MemoryWorkspaceWorkflows();
    workspaces = MemoryWorkspaces(<Workspace>[ws1, ws2]);
    service = WorkflowService(
      repository: globalRepo,
      validator: const WorkflowValidator(),
      workspaceWorkflows: wsWfRepo,
      workspaces: workspaces,
    );
    scopes = McpScopeResolver(
      workspaces: workspaces,
      worktreesDir: r'C:\data\worktrees',
      path: p.context,
    );

    await globalRepo.create(_wf('g-1', 'Global One'));
    await wsWfRepo.create(ws1.rootPath, _wf('w-1', 'Workspace One'));
  });

  test(
    'list_workspaces shows Global and every workspace with counts',
    () async {
      final tool = ListWorkspacesTool(
        workspaces: workspaces,
        globalWorkflows: globalRepo,
        workspaceWorkflows: wsWfRepo,
        formatter: formatter,
      );
      final result = await tool.call(
        const McpToolInput(arguments: <String, Object?>{}),
      );
      expect(
        (result as Success<String>).value,
        'Workspaces (3):\n'
        '- global "Global scope": 1 workflows\n'
        '- ws-1 "App" C:\\repos\\app: 1 workflows\n'
        r'- ws-2 "Lib" C:\repos\lib: 0 workflows',
      );
    },
  );

  test('list_workspaces shows ? when a count fails', () async {
    wsWfRepo.failingRoots.add(ws2.rootPath);
    final tool = ListWorkspacesTool(
      workspaces: workspaces,
      globalWorkflows: globalRepo,
      workspaceWorkflows: wsWfRepo,
      formatter: formatter,
    );
    final result = await tool.call(
      const McpToolInput(arguments: <String, Object?>{}),
    );
    expect(
      (result as Success<String>).value,
      contains(r'- ws-2 "Lib" C:\repos\lib: ? workflows'),
    );
  });

  test('list_workflows in a workspace lists only workspace workflows '
      'plus the global hint', () async {
    final tool = ListWorkflowsTool(
      scopes: scopes,
      workflows: service,
      formatter: formatter,
    );
    final result = await tool.call(
      const McpToolInput(arguments: <String, Object?>{'workspace': 'ws-1'}),
    );
    final text = (result as Success<String>).value;
    expect(
      text,
      startsWith(
        'Scope: workspace "App" (id ws-1, root C:\\repos\\app; from the workspace argument)\n'
        'Workflows (1):\n'
        '- w-1 "Workspace One":',
      ),
    );
    expect(text, isNot(contains('g-1')));
    expect(text, endsWith('Pass workspace=global to see global workflows.'));
  });

  test('list_workflows in Global lists only globals '
      'plus the workspace hint', () async {
    final tool = ListWorkflowsTool(
      scopes: scopes,
      workflows: service,
      formatter: formatter,
    );
    final result = await tool.call(
      const McpToolInput(arguments: <String, Object?>{}),
    );
    final text = (result as Success<String>).value;
    expect(
      text,
      startsWith(
        'Scope: Global (default: no workspace contains the current directory)\n'
        'Workflows (1):\n'
        '- g-1 "Global One":',
      ),
    );
    expect(text, isNot(contains('w-1')));
    expect(
      text,
      endsWith(
        'Pass workspace (id or root path, see list_workspaces) to see a '
        "workspace's workflows.",
      ),
    );
  });

  test('get_workflow compact by default', () async {
    final tool = GetWorkflowTool(
      scopes: scopes,
      workflows: service,
      formatter: formatter,
    );
    final result = await tool.call(
      const McpToolInput(
        arguments: <String, Object?>{'workspace': 'ws-1', 'id': 'w-1'},
      ),
    );
    final text = (result as Success<String>).value;
    expect(
      text,
      startsWith(
        'Scope: workspace "App" (id ws-1, root C:\\repos\\app; from the workspace argument)\n'
        'Workflow w-1 "Workspace One" revision ',
      ),
    );
    expect(text, contains('Entry: n1\n'));
  });

  test('get_workflow full returns header then WorkflowResponse JSON', () async {
    final tool = GetWorkflowTool(
      scopes: scopes,
      workflows: service,
      formatter: formatter,
    );
    final result = await tool.call(
      const McpToolInput(
        arguments: <String, Object?>{
          'workspace': 'ws-1',
          'id': 'w-1',
          'detail': 'full',
        },
      ),
    );
    final lines = (result as Success<String>).value.split('\n');
    expect(lines.length, 2);
    final decoded = WorkflowResponse.fromJson(
      jsonDecode(lines[1]) as Map<String, Object?>,
    );
    expect(decoded.workflow.id, 'w-1');
    expect(decoded.revision, isNotEmpty);
  });

  test('get_workflow unknown id names the scope', () async {
    final tool = GetWorkflowTool(
      scopes: scopes,
      workflows: service,
      formatter: formatter,
    );
    final result = await tool.call(
      const McpToolInput(
        arguments: <String, Object?>{'workspace': 'ws-1', 'id': 'missing'},
      ),
    );
    final failure = (result as FailureResult<String>).failure;
    expect(failure, isA<NotFoundFailure>());
    expect(
      failure.message,
      'Workflow "missing" not found in workspace "App". Call list_workflows to '
      'see the ids, or pass workspace.',
    );
  });

  test('get_workflow missing id', () async {
    final tool = GetWorkflowTool(
      scopes: scopes,
      workflows: service,
      formatter: formatter,
    );
    final result = await tool.call(
      const McpToolInput(arguments: <String, Object?>{}),
    );
    final failure = (result as FailureResult<String>).failure;
    expect(failure, isA<ValidationFailure>());
    expect(
      failure.message,
      'Missing "id": pass a workflow id from list_workflows.',
    );
  });

  test('get_workflow bad detail', () async {
    final tool = GetWorkflowTool(
      scopes: scopes,
      workflows: service,
      formatter: formatter,
    );
    final result = await tool.call(
      const McpToolInput(
        arguments: <String, Object?>{'id': 'g-1', 'detail': 'verbose'},
      ),
    );
    final failure = (result as FailureResult<String>).failure;
    expect(failure, isA<ValidationFailure>());
    expect(failure.message, '"detail" must be "compact" or "full".');
  });
}
