import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
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

import 'support/fakes.dart';

final class _Events implements WorkflowEvents {
  final calls =
      <
        ({
          WorkflowChangeKind kind,
          String id,
          String? workspaceId,
          WorkflowSummary? summary,
        })
      >[];
  @override
  void workflowChanged(
    WorkflowChangeKind kind,
    String id, {
    String? workspaceId,
    WorkflowSummary? workflow,
  }) {
    calls.add((
      kind: kind,
      id: id,
      workspaceId: workspaceId,
      summary: workflow,
    ));
  }
}

void main() {
  late MemoryWorkflows global;
  late MemoryWorkspaceWorkflows workspaceFiles;
  late MemoryWorkspaces workspaces;
  late WorkflowService service;
  late McpScopeResolver scopes;
  late _Events events;
  late CreateWorkflowTool create;
  late DuplicateWorkflowTool duplicate;
  final workspace = Workspace(
    id: 'ws-1',
    name: 'App',
    rootPath: r'C:\repos\app',
    isGit: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() {
    global = MemoryWorkflows();
    workspaceFiles = MemoryWorkspaceWorkflows();
    workspaces = MemoryWorkspaces([workspace]);
    service = WorkflowService(
      repository: global,
      validator: const WorkflowValidator(),
      workspaceWorkflows: workspaceFiles,
      workspaces: workspaces,
    );
    scopes = McpScopeResolver(
      workspaces: workspaces,
      worktreesDir: r'C:\data\worktrees',
      path: p.context,
    );
    events = _Events();
    create = CreateWorkflowTool(
      scopes: scopes,
      workflows: service,
      parser: const WorkflowCreateInputParser(describe: NodeDescriptors.of),
      formatter: const WorkflowTextFormatter(),
      events: events,
    );
    duplicate = DuplicateWorkflowTool(
      scopes: scopes,
      workflows: service,
      formatter: const WorkflowTextFormatter(),
      events: events,
    );
  });

  Map<String, Object?> input({String name = 'Review loop'}) => {
    'name': name,
    'nodes': [
      {
        'id': 'plan',
        'type': 'harness.claude_code',
        'label': 'Plan',
        'config': {'agentId': 'planner'},
      },
    ],
    'edges': [],
    'entryNodeId': 'plan',
  };

  test(
    'creates a global workflow and answers id, revision, scope and validation',
    () async {
      final result = await create.call(McpToolInput(arguments: input()));
      final text = (result as Success<String>).value;
      expect(
        text,
        contains(
          RegExp(r'Created workflow (\S+) "Review loop" revision [0-9a-f]+\n'),
        ),
      );
      expect(text, contains('Scope: Global'));
      expect(text, contains('Validation: ok'));
      expect(global.store, hasLength(1));
      expect(events.calls.single.workspaceId, isNull);
    },
  );

  test(
    'creates in the workspace of the current directory with a slug id',
    () async {
      final result = await create.call(
        McpToolInput(arguments: input(), cwd: r'C:\repos\app\src'),
      );
      expect(result, isA<Success<String>>());
      expect(
        workspaceFiles.byRoot[workspace.rootPath]?.keys,
        contains('review-loop'),
      );
      expect(
        (result as Success<String>).value,
        contains('Scope: workspace "App"'),
      );
      expect(events.calls.single.workspaceId, 'ws-1');
    },
  );

  test('a rejected input saves nothing and sends no event', () async {
    final result = await create.call(
      const McpToolInput(
        arguments: {
          'name': 'Bad',
          'nodes': [
            {'id': 'a', 'type': 'unknown', 'label': 'A'},
            {'id': 'a', 'type': 'unknown', 'label': 'A2'},
          ],
          'edges': [],
          'entryNodeId': 'a',
        },
      ),
    );
    expect(result, isA<FailureResult<String>>());
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(global.store, isEmpty);
    expect(events.calls, isEmpty);
  });

  test('emits a created event with the summary', () async {
    final result = await create.call(McpToolInput(arguments: input()));
    final response = (result as Success<String>).value;
    final createdLine = response
        .split('\n')
        .firstWhere((line) => line.startsWith('Created workflow '));
    final id = RegExp(r'^Created workflow (\S+)')
        .firstMatch(createdLine)!
        .group(1)!;
    expect(events.calls.single.kind, WorkflowChangeKind.created);
    expect(events.calls.single.id, id);
    expect(
      events.calls.single.summary?.revision,
      matches(RegExp(r'^[0-9a-f]+$')),
    );
  });

  test(
    'a graph-invalid workflow is saved as a draft and the errors come back',
    () async {
      final result = await create.call(
        McpToolInput(
          arguments: {
            'name': 'Cycle',
            'nodes': [_node('a'), _node('b')],
            'edges': [
              {'from': 'a', 'to': 'b', 'output': 'onSuccess'},
              {'from': 'b', 'to': 'a', 'output': 'onSuccess'},
            ],
            'entryNodeId': 'a',
          },
        ),
      );
      final text = (result as Success<String>).value;
      expect(global.store, hasLength(1));
      expect(text, contains('Validation (1 errors'));
      expect(text, endsWith(CreateWorkflowTool.draftLine));
    },
  );

  test('warnings only do not add the draft line', () async {
    final result = await create.call(
      McpToolInput(
        arguments: {
          'name': 'Unreachable',
          'nodes': [_node('a'), _node('z')],
          'edges': [],
          'entryNodeId': 'a',
        },
      ),
    );
    final text = (result as Success<String>).value;
    expect(text, contains('warnings'));
    expect(text, isNot(contains(CreateWorkflowTool.draftLine)));
  });

  test('the saved workflow opens in the editor', () async {
    await create.call(McpToolInput(arguments: input()));
    final saved = global.store.values.single;
    expect(saved.nodes, isNotEmpty);
    expect(
      saved.nodes.single.config.keys,
      containsAll(
        NodeDescriptors.of(saved.nodes.single.type)!.defaultConfig().keys,
      ),
    );
    expect(
      Workflow.fromJson(jsonDecode(jsonEncode(saved.toJson())) as JsonMap),
      saved,
    );
  });

  test('duplicates a global workflow with the default name', () async {
    await create.call(McpToolInput(arguments: input(name: 'Global One')));
    final sourceId = global.store.keys.single;
    final result = await duplicate.call(
      McpToolInput(arguments: {'id': sourceId}),
    );
    expect((result as Success<String>).value, contains('"Global One (Copy)"'));
  });

  test('emits a created event for the copy', () async {
    await create.call(McpToolInput(arguments: input()));
    final sourceId = global.store.keys.single;
    final result = await duplicate.call(
      McpToolInput(arguments: {'id': sourceId}),
    );
    final copyId = RegExp(r' as (\S+) ')
        .firstMatch((result as Success<String>).value)!
        .group(1)!;
    expect(events.calls.last.kind, WorkflowChangeKind.created);
    expect(events.calls.last.id, copyId);
    expect(events.calls.last.summary?.revision, isNotNull);
  });

  test('a draft copy gets the draft line', () async {
    await create.call(
      McpToolInput(
        arguments: {
          'name': 'Cycle',
          'nodes': [_node('a'), _node('b')],
          'edges': [
            {'from': 'a', 'to': 'b', 'output': 'onSuccess'},
            {'from': 'b', 'to': 'a', 'output': 'onSuccess'},
          ],
          'entryNodeId': 'a',
        },
      ),
    );
    final copied = await duplicate.call(
      McpToolInput(arguments: {'id': global.store.keys.single}),
    );
    expect(
      (copied as Success<String>).value,
      endsWith(CreateWorkflowTool.draftLine),
    );
  });

  test(
    'duplicates a workspace workflow with a new name in the same workspace',
    () async {
      await create.call(
        McpToolInput(arguments: {...input(), 'workspace': 'ws-1'}),
      );
      final result = await duplicate.call(
        const McpToolInput(
          arguments: {
            'id': 'review-loop',
            'workspace': 'ws-1',
            'name': 'Second',
          },
        ),
      );
      expect(result, isA<Success<String>>());
      expect(
        workspaceFiles.byRoot[workspace.rootPath]?.keys,
        contains('second'),
      );
    },
  );

  test('unknown id names the scope', () async {
    final result = await duplicate.call(
      const McpToolInput(arguments: {'id': 'missing'}),
    );
    expect(result.failureOrNull, isA<NotFoundFailure>());
    expect(result.failureOrNull!.message, contains('Global scope'));
  });

  test('missing id', () async {
    final result = await duplicate.call(const McpToolInput(arguments: {}));
    expect(
      result.failureOrNull?.message,
      'Missing "id": pass a workflow id from list_workflows.',
    );
  });

  test('non-string name', () async {
    await create.call(McpToolInput(arguments: input(name: 'Global One')));
    final result = await duplicate.call(
      McpToolInput(arguments: {'id': global.store.keys.single, 'name': 3}),
    );
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(result.failureOrNull!.message, contains('name'));
    expect(global.store, hasLength(1));
  });
}

Map<String, Object?> _node(String id) => {
  'id': id,
  'type': 'harness.claude_code',
  'label': id.toUpperCase(),
  'config': {'agentId': 'planner'},
};
