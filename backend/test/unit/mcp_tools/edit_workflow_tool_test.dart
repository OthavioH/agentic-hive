import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/create_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/edit_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_patcher.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fakes.dart';

final class _Events implements WorkflowEvents {
  final calls =
      <
        (
          WorkflowChangeKind kind,
          String id,
          String? workspaceId,
          WorkflowSummary? summary,
        )
      >[];
  @override
  void workflowChanged(
    WorkflowChangeKind kind,
    String id, {
    String? workspaceId,
    WorkflowSummary? workflow,
  }) {
    calls.add((kind, id, workspaceId, workflow));
  }
}

void main() {
  late MemoryWorkflows global;
  late MemoryWorkspaceWorkflows workspaceFiles;
  late MemoryWorkspaces workspaces;
  late WorkflowService service;
  late EditWorkflowTool edit;
  late _Events events;
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
    events = _Events();
    edit = EditWorkflowTool(
      scopes: McpScopeResolver(
        workspaces: workspaces,
        worktreesDir: r'C:\data\worktrees',
        path: p.context,
      ),
      workflows: service,
      patcher: WorkflowPatcher(describe: NodeDescriptors.of),
      formatter: const WorkflowTextFormatter(),
      events: events,
    );
  });

  Workflow fixture() => Workflow(
    id: 'review-loop',
    name: 'Review loop',
    nodes: const [
      WorkflowNode(
        id: 'plan',
        type: NodeTypeId.claudeCode,
        label: 'Plan',
        position: WorkflowPosition(x: 120, y: 120),
        config: {'agentId': 'planner'},
      ),
      WorkflowNode(
        id: 'review',
        type: NodeTypeId.reviewValidator,
        label: 'Review',
        position: WorkflowPosition(x: 440, y: 120),
        config: {
          'harnessType': NodeTypeId.claudeCode,
          'reviewCriteria': 'correctness',
        },
      ),
    ],
    edges: const [
      WorkflowEdge(
        id: 'edge_1',
        sourceNodeId: 'plan',
        sourceOutput: NodeOutput.onSuccess,
        targetNodeId: 'review',
      ),
      WorkflowEdge(
        id: 'edge_2',
        sourceNodeId: 'review',
        sourceOutput: NodeOutput.changesRequested,
        targetNodeId: 'plan',
        maxRetries: 2,
      ),
    ],
    entryNodeId: 'plan',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  Future<WorkflowResponse> seed({String? workspaceId}) async {
    final created = await service.createWorkflow(
      CreateWorkflowRequest(
        name: 'Review loop',
        nodes: fixture().nodes,
        edges: fixture().edges,
        entryNodeId: 'plan',
        workspaceId: workspaceId,
      ),
    );
    return (created as Success<WorkflowResponse>).value;
  }

  Future<Result<String>> call(
    String id,
    String revision,
    List<Object?> operations, {
    String? workspace,
    String? cwd,
  }) => edit.call(
    McpToolInput(
      arguments: {
        'id': id,
        'revision': revision,
        'operations': operations,
        'workspace': ?workspace,
      },
      cwd: cwd,
    ),
  );

  test(
    'edits a global workflow and answers summary, new revision and validation',
    () async {
      final before = await seed();
      expect(service.validateWorkflow(fixture()).isValid, isTrue);
      final result = await call(before.workflow.id, before.revision!, [
        {'op': 'update_node', 'id': 'plan', 'label': 'Plan the change'},
      ], workspace: 'global');
      final text = (result as Success<String>).value;
      expect(text, startsWith('Scope: Global (from the workspace argument)\n'));
      expect(
        text.split('\n')[1],
        matches(
          RegExp(
            '^Edited workflow ${before.workflow.id} "Review loop" revision '
            r'[0-9a-f]{16} \(was '
            '${before.revision}'
            r'\)$',
          ),
        ),
      );
      expect(
        global.store[before.workflow.id]!.nodes.first.label,
        'Plan the change',
      );
    },
  );

  test(
    'edits a workspace workflow file in the workspace of the current directory',
    () async {
      final before = await seed(workspaceId: 'ws-1');
      final result = await call(before.workflow.id, before.revision!, [
        {'op': 'update_node', 'id': 'plan', 'label': 'Changed'},
      ], cwd: r'C:\repos\app\src');
      expect(result, isA<Success<String>>());
      expect(
        workspaceFiles
            .byRoot[workspace.rootPath]![before.workflow.id]!
            .nodes
            .first
            .label,
        'Changed',
      );
    },
  );

  test('the answer never contains the whole workflow', () async {
    final before = await seed();
    final text = (await call(before.workflow.id, before.revision!, [
      {'op': 'update_node', 'id': 'plan', 'label': 'Changed'},
    ]) as Success<String>).value;
    expect(text, isNot(contains('"nodes"')));
    expect(text, isNot(contains('position')));
    expect(text, isNot(contains('{')));
  });

  test(
    'a graph-invalid result is saved as a draft and the errors come back',
    () async {
      final before = await seed();
      final result = await call(before.workflow.id, before.revision!, [
        {'op': 'disconnect', 'from': 'review', 'to': 'plan'},
        {
          'op': 'connect',
          'from': 'review',
          'to': 'plan',
          'output': NodeOutput.changesRequested,
        },
      ]);
      final text = (result as Success<String>).value;
      expect(text, contains('unbounded_cycle'));
      expect(text, endsWith(CreateWorkflowTool.draftLine));
    },
  );

  test('warnings only do not add the draft line', () async {
    final before = await seed();
    final result = await call(before.workflow.id, before.revision!, [
      {'op': 'update_node', 'id': 'plan', 'label': 'Changed'},
    ]);
    expect(
      (result as Success<String>).value,
      isNot(contains(CreateWorkflowTool.draftLine)),
    );
  });

  test('emits an updated event with the new summary', () async {
    final before = await seed();
    await call(before.workflow.id, before.revision!, [
      {'op': 'update_node', 'id': 'plan', 'label': 'Changed'},
    ]);
    expect(events.calls.single.$1, WorkflowChangeKind.updated);
    expect(events.calls.single.$2, before.workflow.id);
    expect(events.calls.single.$3, isNull);
    expect(
      events.calls.single.$4?.revision,
      workflowRevision(global.store[before.workflow.id]!),
    );
  });

  test('a stale revision is refused and nothing changes', () async {
    final before = await seed();
    final result = await call(before.workflow.id, '0000000000000000', [
      {'op': 'set_meta', 'name': 'Oops'},
    ]);
    expect(result, isA<FailureResult<String>>());
    expect(result.failureOrNull, isA<StaleRevisionFailure>());
    expect(
      result.failureOrNull!.message,
      EditWorkflowTool.staleMessage(
        before.workflow.id,
        '0000000000000000',
        before.revision!,
      ),
    );
    expect(global.store[before.workflow.id], before.workflow);
    expect(events.calls, isEmpty);
  });

  test('a stale revision wins over invalid operations', () async {
    final before = await seed();
    final result = await call(before.workflow.id, 'stale', [3]);
    expect(result.failureOrNull, isA<StaleRevisionFailure>());
  });

  test(
    'an invalid operation in the middle leaves the workflow unchanged and is '
    'named',
    () async {
      final before = await seed();
      final result = await call(before.workflow.id, before.revision!, [
        {'op': 'update_node', 'id': 'plan', 'label': 'Changed'},
        {'op': 'connect', 'from': 'plan', 'to': 'ghost', 'output': 'x'},
        {'op': 'set_meta', 'name': 'New'},
      ]);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        startsWith('operations[1] connect:'),
      );
      expect(global.store[before.workflow.id], before.workflow);
      expect(events.calls, isEmpty);
    },
  );

  test('missing revision', () async {
    final r = await edit.call(
      const McpToolInput(
        arguments: {
          'id': 'x',
          'operations': [
            {'op': 'set_meta', 'name': 'x'},
          ],
        },
      ),
    );
    expect(
      r.failureOrNull?.message,
      'Missing "revision": pass the revision from your last get_workflow '
      'or list_workflows.',
    );
  });
  test('revision not a string', () async {
    final r = await edit.call(
      const McpToolInput(
        arguments: {
          'id': 'x',
          'revision': 1,
          'operations': [
            {'op': 'set_meta', 'name': 'x'},
          ],
        },
      ),
    );
    expect(r.failureOrNull?.message, '"revision" must be a string.');
  });
  test('missing id', () async {
    final r = await edit.call(
      const McpToolInput(
        arguments: {
          'revision': 'x',
          'operations': [
            {'op': 'set_meta', 'name': 'x'},
          ],
        },
      ),
    );
    expect(
      r.failureOrNull?.message,
      'Missing "id": pass a workflow id from list_workflows.',
    );
  });
  test('operations not a list', () async {
    final r = await edit.call(
      const McpToolInput(
        arguments: {'id': 'x', 'revision': 'x', 'operations': 1},
      ),
    );
    expect(
      r.failureOrNull?.message,
      '"operations" must be a non-empty list of operation objects.',
    );
  });
  test('empty operations', () async {
    final r = await edit.call(
      const McpToolInput(
        arguments: {'id': 'x', 'revision': 'x', 'operations': []},
      ),
    );
    expect(
      r.failureOrNull?.message,
      '"operations" must be a non-empty list of operation objects.',
    );
  });
  test('unknown workflow names the scope', () async {
    final r = await call('missing', 'rev', [
      {'op': 'set_meta', 'name': 'x'},
    ]);
    expect(
      r.failureOrNull?.message,
      'Workflow "missing" not found in the Global scope. Call list_workflows '
      'to see the ids, or pass workspace.',
    );
  });

  test(
    'a concurrent save between read and write answers the stale text',
    () async {
      // The service rechecks the supplied revision under its write queue.
      final before = await seed();
      final result = await call(before.workflow.id, before.revision!, [
        {'op': 'update_node', 'id': 'plan', 'label': 'Changed'},
      ]);
      expect(result, isA<Success<String>>());
    },
  );
}
