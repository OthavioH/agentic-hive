import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

Workflow _workflow({
  String id = 'review-loop',
  String name = 'Review loop',
  String? description,
  String entryNodeId = 'plan',
  List<WorkflowNode>? nodes,
  List<WorkflowEdge>? edges,
}) => Workflow(
  id: id,
  name: name,
  description: description,
  entryNodeId: entryNodeId,
  nodes:
      nodes ??
      <WorkflowNode>[
        const WorkflowNode(
          id: 'plan',
          type: 'harness.claude_code',
          label: 'Plan',
          position: WorkflowPosition(x: 100, y: 200),
          config: <String, Object?>{'agentId': 'planner'},
        ),
        const WorkflowNode(
          id: 'review',
          type: 'validator.review',
          label: 'Review',
          position: WorkflowPosition(x: 300, y: 200),
          config: <String, Object?>{
            'harnessType': 'codex',
            'reviewCriteria': 'Check the tests pass.',
          },
        ),
      ],
  edges:
      edges ??
      const <WorkflowEdge>[
        WorkflowEdge(
          id: 'e1',
          sourceNodeId: 'plan',
          sourceOutput: 'onSuccess',
          targetNodeId: 'review',
        ),
        WorkflowEdge(
          id: 'e2',
          sourceNodeId: 'review',
          sourceOutput: 'onFailure',
          targetNodeId: 'plan',
          maxRetries: 2,
        ),
      ],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  const formatter = WorkflowTextFormatter();

  test('compact workflow matches the documented example', () {
    final response = WorkflowResponse(
      workflow: _workflow(),
      validation: const WorkflowValidationResult(isValid: true),
      revision: '0123456789abcdef',
    );
    expect(
      formatter.workflow(response),
      'Workflow review-loop "Review loop" revision 0123456789abcdef\n'
      'Entry: plan\n'
      'Nodes (2):\n'
      '- plan (harness.claude_code) "Plan" agentId=planner\n'
      '- review (validator.review) "Review" harnessType=codex '
      'reviewCriteria="Check the tests pass."\n'
      'Edges (2):\n'
      '- plan -onSuccess-> review\n'
      '- review -onFailure-> plan (maxRetries 2)\n'
      'Validation: ok',
    );
  });

  test('description line only when non-blank', () {
    final withDesc = WorkflowResponse(
      workflow: _workflow(description: 'Runs a review loop'),
      validation: const WorkflowValidationResult(isValid: true),
      revision: 'rev1',
    );
    expect(
      formatter.workflow(withDesc),
      contains(
        'Workflow review-loop "Review loop" revision rev1\n'
        'Description: Runs a review loop\n'
        'Entry: plan',
      ),
    );

    final blankDesc = WorkflowResponse(
      workflow: _workflow(description: '   '),
      validation: const WorkflowValidationResult(isValid: true),
      revision: 'rev1',
    );
    expect(formatter.workflow(blankDesc), isNot(contains('Description:')));
  });

  test('default config values and empties are omitted', () {
    final defaults = NodeDescriptors.byTypeId['harness.claude_code']!
        .defaultConfig();
    final response = WorkflowResponse(
      workflow: _workflow(
        nodes: <WorkflowNode>[
          WorkflowNode(
            id: 'n1',
            type: 'harness.claude_code',
            label: 'N1',
            position: const WorkflowPosition(x: 1, y: 2),
            config: <String, Object?>{
              ...defaults,
              'emptyStr': '',
              'nullVal': null,
              'emptyList': <Object?>[],
              'emptyMap': <String, Object?>{},
              'agentId': 'coder',
            },
          ),
        ],
        edges: const <WorkflowEdge>[],
      ),
      validation: const WorkflowValidationResult(isValid: true),
      revision: 'rev1',
    );
    final out = formatter.workflow(response);
    expect(out, contains('- n1 (harness.claude_code) "N1" agentId=coder\n'));
  });

  test('long strings are cut to 80 characters', () {
    final longValue = 'a' * 90;
    final response = WorkflowResponse(
      workflow: _workflow(
        nodes: <WorkflowNode>[
          WorkflowNode(
            id: 'n1',
            type: 'unknown.custom',
            label: 'N1',
            position: const WorkflowPosition(x: 0, y: 0),
            config: <String, Object?>{'prompt': longValue},
          ),
        ],
        edges: const <WorkflowEdge>[],
      ),
      validation: const WorkflowValidationResult(isValid: true),
      revision: 'rev1',
    );
    final out = formatter.workflow(response);
    expect(out, contains('prompt=${'a' * 77}...'));
    expect(out, isNot(contains('a' * 78)));
  });

  test('strings with spaces are quoted', () {
    final response = WorkflowResponse(
      workflow: _workflow(
        nodes: <WorkflowNode>[
          const WorkflowNode(
            id: 'n1',
            type: 'unknown.custom',
            label: 'N1',
            position: WorkflowPosition(x: 0, y: 0),
            config: <String, Object?>{'msg': 'hello world'},
          ),
        ],
        edges: const <WorkflowEdge>[],
      ),
      validation: const WorkflowValidationResult(isValid: true),
      revision: 'rev1',
    );
    expect(formatter.workflow(response), contains('msg="hello world"'));
  });

  test('validation header counts errors and warnings', () {
    final response = WorkflowResponse(
      workflow: _workflow(edges: const <WorkflowEdge>[]),
      revision: 'rev1',
      validation: const WorkflowValidationResult(
        isValid: false,
        issues: <WorkflowValidationIssue>[
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: 'MISSING_ENTRY',
            message: 'Entry missing',
            nodeId: 'plan',
          ),
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.warning,
            code: 'ORPHAN_EDGE',
            message: 'Orphan',
            edgeId: 'e1',
          ),
        ],
      ),
    );
    final out = formatter.workflow(response);
    expect(
      out,
      contains(
        'Validation (1 errors, 1 warnings):\n'
        '- error MISSING_ENTRY node plan: Entry missing\n'
        '- warning ORPHAN_EDGE edge e1: Orphan',
      ),
    );
  });

  test('positions are never printed', () {
    final response = WorkflowResponse(
      workflow: _workflow(
        nodes: <WorkflowNode>[
          const WorkflowNode(
            id: 'n1',
            type: 'unknown.custom',
            label: 'N1',
            position: WorkflowPosition(x: 12345, y: 67890),
          ),
        ],
        edges: const <WorkflowEdge>[],
      ),
      validation: const WorkflowValidationResult(isValid: true),
      revision: 'rev1',
    );
    final out = formatter.workflow(response);
    expect(out, isNot(contains('12345')));
    expect(out, isNot(contains('67890')));
  });

  test('summaries list with hint', () {
    final items = <WorkflowSummary>[
      WorkflowSummary(
        id: 'wf-1',
        name: 'First',
        nodeCount: 2,
        edgeCount: 1,
        hasValidationErrors: false,
        scope: const WorkspaceScope('ws-1'),
        revision: 'rev-a',
        updatedAt: DateTime.utc(2026),
      ),
      WorkflowSummary(
        id: 'wf-2',
        name: 'Second',
        nodeCount: 3,
        edgeCount: 2,
        hasValidationErrors: true,
        scope: const WorkspaceScope('ws-1'),
        revision: 'rev-b',
        updatedAt: DateTime.utc(2026),
      ),
    ];
    expect(
      formatter.summaries(items, hint: 'Pass workspace=global.'),
      'Workflows (2):\n'
      '- wf-1 "First": 2 nodes, 1 edges, revision rev-a\n'
      '- wf-2 "Second": 3 nodes, 2 edges, revision rev-b, '
      'has validation errors\n'
      'Pass workspace=global.',
    );
  });

  test('empty summaries say no workflows', () {
    expect(
      formatter.summaries(const <WorkflowSummary>[], hint: 'Hint line.'),
      'No workflows in this scope.\nHint line.',
    );
  });

  test('workspaces list with Global first and unknown counts', () {
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
      name: 'Broken',
      rootPath: r'C:\repos\broken',
      isGit: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    expect(
      formatter.workspaces(
        globalCount: 3,
        items: <({Workspace workspace, int? count})>[
          (workspace: ws1, count: 2),
          (workspace: ws2, count: null),
        ],
      ),
      'Workspaces (3):\n'
      '- global "Global scope": 3 workflows\n'
      '- ws-1 "App" C:\\repos\\app: 2 workflows\n'
      r'- ws-2 "Broken" C:\repos\broken: ? workflows',
    );
  });
}
