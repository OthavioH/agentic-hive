import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_patcher.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  final workflow = Workflow(
    id: 'review-loop',
    name: 'Review loop',
    nodes: const [
      WorkflowNode(
        id: 'plan',
        type: NodeTypeId.claudeCode,
        label: 'Plan',
        position: WorkflowPosition(x: 120, y: 120),
        config: {'old': true},
      ),
      WorkflowNode(
        id: 'review',
        type: NodeTypeId.reviewValidator,
        label: 'Review',
        position: WorkflowPosition(x: 440, y: 120),
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
  final patcher = WorkflowPatcher(describe: NodeDescriptors.of);
  WorkflowPatch apply(List<Object?> ops) =>
      (patcher.apply(workflow, ops) as Success<WorkflowPatch>).value;
  String error(List<Object?> ops) =>
      (patcher.apply(workflow, ops) as FailureResult).failure.message;

  test('add_node appends a node with defaults merged and a given position', () {
    final patch = apply([
      {
        'op': 'add_node',
        'id': 'fix',
        'type': NodeTypeId.claudeCode,
        'label': ' Fix ',
        'config': {'extra': 1},
        'position': {'x': 760, 'y': 120},
      },
    ]);
    expect(patch.nodes.last.id, 'fix');
    expect(patch.nodes.last.label, 'Fix');
    expect(patch.nodes.last.config['extra'], 1);
    expect(patch.nodes.last.config['additionalInstructions'], '');
    expect(patch.nodes.last.position, const WorkflowPosition(x: 760, y: 120));
  });
  test('add_node without position is auto-placed next to its predecessor', () {
    final patch = apply([
      {'op': 'add_node', 'id': 'fix', 'type': 'custom', 'label': 'Fix'},
      {
        'op': 'connect',
        'from': 'review',
        'to': 'fix',
        'output': NodeOutput.changesRequested,
      },
    ]);
    expect(patch.nodes.last.position, const WorkflowPosition(x: 760, y: 120));
  });
  test(
    'update_node changes the label',
    () => expect(
      apply([
        {'op': 'update_node', 'id': 'plan', 'label': 'Plan it'},
      ]).nodes.first.label,
      'Plan it',
    ),
  );
  test('update_node merges config and null removes a key', () {
    final patch = apply([
      {
        'op': 'update_node',
        'id': 'plan',
        'config': {'old': null, 'new': true},
      },
    ]);
    expect(patch.nodes.first.config, {'new': true});
  });

  test('update_node type changes a headless harness and keeps id, label, '
      'position, edges and supported config', () {
    final patch = apply([
      {
        'op': 'add_node',
        'id': 'h1',
        'type': NodeTypeId.claudeCode,
        'label': 'Agent',
        'position': {'x': 10, 'y': 20},
        'config': {
          'agentId': 'a',
          'model': 'm',
          'effort': 'high',
          'extraArgs': ['--x'],
        },
      },
      {'op': 'update_node', 'id': 'h1', 'type': NodeTypeId.codex},
    ]);
    final h1 = patch.nodes.firstWhere((n) => n.id == 'h1');
    expect(h1.type, NodeTypeId.codex);
    expect(h1.label, 'Agent');
    expect(h1.position, const WorkflowPosition(x: 10, y: 20));
    expect(h1.config, {
      'additionalInstructions': '',
      'agentId': 'a',
      'model': 'm',
      'effort': 'high',
      'extraArgs': ['--x'],
    });
    expect(patch.edges, hasLength(2));
    expect(
      patch.tally.typeChanges.single,
      'h1: ${NodeTypeId.claudeCode} -> ${NodeTypeId.codex}, '
      'dropped config fields: none',
    );
  });

  test('update_node type to gemini_cli drops effort and names it in tally', () {
    final patch = apply([
      {
        'op': 'add_node',
        'id': 'h1',
        'type': NodeTypeId.claudeCode,
        'label': 'Agent',
        'config': {'agentId': 'a', 'effort': 'high'},
      },
      {'op': 'update_node', 'id': 'h1', 'type': NodeTypeId.geminiCli},
    ]);
    final h1 = patch.nodes.firstWhere((n) => n.id == 'h1');
    expect(h1.type, NodeTypeId.geminiCli);
    expect(h1.config, {
      'additionalInstructions': '',
      'extraArgs': <Object?>[],
      'agentId': 'a',
    });
    expect(
      patch.tally.typeChanges.single,
      'h1: ${NodeTypeId.claudeCode} -> ${NodeTypeId.geminiCli}, '
      'dropped config fields: effort',
    );
  });

  test('update_node with same type is a no-op for type and config', () {
    final patch = apply([
      {'op': 'update_node', 'id': 'plan', 'type': NodeTypeId.claudeCode},
    ]);
    expect(patch.nodes.first.type, NodeTypeId.claudeCode);
    expect(patch.nodes.first.config, {'old': true});
    expect(patch.tally.typeChanges, isEmpty);
  });

  test('update_node type plus config in one op drops unsupported config', () {
    final patch = apply([
      {
        'op': 'update_node',
        'id': 'plan',
        'type': NodeTypeId.geminiCli,
        'config': {'old': null, 'effort': 'low', 'model': 'gemini-2.5-pro'},
      },
    ]);
    expect(patch.nodes.first.type, NodeTypeId.geminiCli);
    expect(patch.nodes.first.config, {'model': 'gemini-2.5-pro'});
    expect(
      patch.tally.typeChanges.single,
      'plan: ${NodeTypeId.claudeCode} -> ${NodeTypeId.geminiCli}, '
      'dropped config fields: effort',
    );
  });
  test('remove_node removes the node and its edges', () {
    final patch = apply([
      {'op': 'remove_node', 'id': 'review'},
    ]);
    expect(patch.nodes.map((n) => n.id), ['plan']);
    expect(patch.edges, isEmpty);
    expect(patch.tally.edgesRemoved, 2);
  });
  test(
    'remove_node of the entry clears the entry',
    () => expect(
      apply([
        {'op': 'remove_node', 'id': 'plan'},
      ]).entryNodeId,
      isNull,
    ),
  );
  test(
    'connect adds edge_3',
    () => expect(
      apply([
        {
          'op': 'connect',
          'from': 'plan',
          'to': 'review',
          'output': NodeOutput.onFailure,
        },
      ]).edges.last.id,
      'edge_3',
    ),
  );
  test('connect from an unknown-type node accepts any output', () {
    final withUnknown = workflow.copyWith(
      nodes: [
        workflow.nodes.first.copyWith(type: 'custom'),
        workflow.nodes.last,
      ],
    );
    expect(
      (patcher.apply(withUnknown, [
        {'op': 'connect', 'from': 'plan', 'to': 'review', 'output': 'anything'},
      ]) as Success<WorkflowPatch>).value.edges.length,
      3,
    );
  });
  test(
    'disconnect removes the matching edge',
    () => expect(
      apply([
        {
          'op': 'disconnect',
          'from': 'plan',
          'to': 'review',
          'output': NodeOutput.onSuccess,
        },
      ]).edges,
      hasLength(1),
    ),
  );
  test(
    'disconnect without output removes every edge between the two nodes',
    () {
      final changed = workflow.copyWith(
        edges: [
          ...workflow.edges,
          const WorkflowEdge(
            id: 'edge_3',
            sourceNodeId: 'plan',
            sourceOutput: NodeOutput.onFailure,
            targetNodeId: 'review',
          ),
        ],
      );
      expect(
        (patcher.apply(changed, [
          {'op': 'disconnect', 'from': 'plan', 'to': 'review'},
        ]) as Success<WorkflowPatch>).value.edges,
        hasLength(1),
      );
    },
  );
  test(
    'set_entry changes the entry',
    () => expect(
      apply([
        {'op': 'set_entry', 'id': 'review'},
      ]).entryNodeId,
      'review',
    ),
  );
  test('set_meta changes name and description', () {
    final patch = apply([
      {'op': 'set_meta', 'name': ' New ', 'description': ' Desc '},
    ]);
    expect(patch.name, 'New');
    expect(patch.description, 'Desc');
  });
  test(
    'set_meta with blank description clears it',
    () => expect(
      apply([
        {'op': 'set_meta', 'description': '  '},
      ]).description,
      isNull,
    ),
  );
  test('operations see earlier operations in the same call', () {
    final patch = apply([
      {'op': 'add_node', 'id': 'fix', 'type': 'custom', 'label': 'Fix'},
      {
        'op': 'connect',
        'from': 'review',
        'to': 'fix',
        'output': NodeOutput.changesRequested,
      },
      {'op': 'set_entry', 'id': 'fix'},
    ]);
    expect(patch.entryNodeId, 'fix');
    expect(patch.edges.last.id, 'edge_3');
  });
  test('five combined operations give the expected workflow', () {
    final patch = apply([
      {
        'op': 'add_node',
        'id': 'fix_tests',
        'type': NodeTypeId.claudeCode,
        'label': 'Fix tests',
      },
      {
        'op': 'connect',
        'from': 'review',
        'to': 'fix_tests',
        'output': NodeOutput.changesRequested,
        'maxRetries': 2,
      },
      {'op': 'disconnect', 'from': 'review', 'to': 'plan'},
      {'op': 'update_node', 'id': 'plan', 'label': 'Plan the change'},
      {'op': 'set_meta', 'description': 'Plans, reviews and fixes.'},
    ]);
    expect(patch.nodes, hasLength(3));
    expect(patch.edges.map((e) => e.id), ['edge_1', 'edge_3']);
    expect(patch.nodes.first.label, 'Plan the change');
    expect(patch.description, 'Plans, reviews and fixes.');
    expect(
      patch.tally.describe(),
      '1 nodes added (1 auto-placed), 1 nodes updated, 1 edges added, '
      '1 edges removed, name or description changed',
    );
  });
  test('an invalid operation in the middle names its index and leaves the '
      'input unchanged', () {
    final before = workflow.copyWith();
    expect(
      error([
        {'op': 'update_node', 'id': 'plan', 'label': 'Changed'},
        {'op': 'connect', 'from': 'plan', 'to': 'ghost', 'output': 'x'},
        {'op': 'set_meta', 'name': 'New'},
      ]),
      startsWith(
        'operations[1] connect: to "ghost" is not a node of the workflow.',
      ),
    );
    expect(workflow, before);
  });
  test(
    'a removed node cannot be used later in the same call',
    () => expect(
      error([
        {'op': 'remove_node', 'id': 'review'},
        {'op': 'connect', 'from': 'plan', 'to': 'review', 'output': 'x'},
      ]),
      startsWith(
        'operations[1] connect: to "review" is not a node of the workflow.',
      ),
    ),
  );
  test(
    'the first invalid operation wins',
    () => expect(
      error([
        {'op': 'set_entry', 'id': 'ghost'},
        {'op': 'set_meta', 'name': 'x'},
        {'op': 'set_entry', 'id': 'other'},
      ]),
      startsWith('operations[0]'),
    ),
  );

  final invalids = <String, Object?>{
    'element not an object':
        'operations[0] must be an object with an "op" field. Nothing '
        'was applied.',
    'missing op':
        'operations[0].op is missing; use one of: add_node, '
        'update_node, remove_node, connect, disconnect, set_entry, '
        'set_meta. Nothing was applied.',
    'unknown op lists the operations':
        'operations[0].op "wat" is not an operation; use one of: '
        'add_node, update_node, remove_node, connect, disconnect, '
        'set_entry, set_meta. Nothing was applied.',
    'add_node id not a string':
        'operations[0] add_node: id must be a node id. Nothing was applied.',
    'add_node bad id pattern':
        'operations[0] add_node: id "bad-id" is not a valid node id: '
        'use 1-32 lowercase letters, digits or _, starting with a '
        'letter (for example review or fix_tests). Nothing was '
        'applied.',
    'add_node duplicate id':
        'operations[0] add_node: node "plan" already exists. Nothing '
        'was applied.',
    'add_node blank type':
        'operations[0] add_node: type must be a non-blank string. '
        'Nothing was applied.',
    'add_node blank label':
        'operations[0] add_node: label must be a non-blank string. '
        'Nothing was applied.',
    'add_node config not an object':
        'operations[0] add_node: config must be an object. Nothing '
        'was applied.',
    'add_node bad position':
        'operations[0] add_node: position must be {"x": number, "y": '
        'number}. Nothing was applied.',
    'update_node unknown node':
        'operations[0] update_node: node "ghost" does not exist. '
        'Nothing was applied.',
    'update_node nothing to change':
        'operations[0] update_node: pass label, config or type. '
        'Nothing was applied.',
    'update_node type to terminal is refused':
        'operations[0] update_node: cannot change type from '
        '${NodeTypeId.claudeCode} to ${NodeTypeId.terminal}: only the headless '
        'harnesses (${headlessHarnessTypeIds.join(', ')}) can change into one '
        'another; use remove_node and add_node. Nothing was applied.',
    'update_node type from review validator is refused':
        'operations[0] update_node: cannot change type from '
        '${NodeTypeId.reviewValidator} to ${NodeTypeId.codex}: only the '
        'headless harnesses (${headlessHarnessTypeIds.join(', ')}) can change '
        'into one another; use remove_node and add_node. Nothing was applied.',
    'update_node type to command is refused':
        'operations[0] update_node: cannot change type from '
        '${NodeTypeId.claudeCode} to ${NodeTypeId.command}: only the headless '
        'harnesses (${headlessHarnessTypeIds.join(', ')}) can change into one '
        'another; use remove_node and add_node. Nothing was applied.',
    'update_node unknown type is refused':
        'operations[0] update_node: cannot change type from '
        '${NodeTypeId.claudeCode} to x: only the headless harnesses '
        '(${headlessHarnessTypeIds.join(', ')}) can change into one another; '
        'use remove_node and add_node. Nothing was applied.',
    'update_node non-string type':
        'operations[0] update_node: type must be a non-blank string. '
        'Nothing was applied.',
    'update_node blank label':
        'operations[0] update_node: label must be a non-blank string. '
        'Nothing was applied.',
    'update_node config not an object':
        'operations[0] update_node: config must be an object. Nothing '
        'was applied.',
    'remove_node unknown node':
        'operations[0] remove_node: node "ghost" does not exist. '
        'Nothing was applied.',
    'connect unknown from':
        'operations[0] connect: from "ghost" is not a node of the '
        'workflow. Nothing was applied.',
    'connect unknown to':
        'operations[0] connect: to "ghost" is not a node of the '
        'workflow. Nothing was applied.',
    'connect blank output':
        'operations[0] connect: output must be a non-blank string. '
        'Nothing was applied.',
    'connect output not allowed lists the outputs':
        'operations[0] connect: output "bad" is not an output of '
        'validator.review (node "review"); use one of: approved, '
        'changesRequested. Nothing was applied.',
    'connect maxRetries not an integer':
        'operations[0] connect: maxRetries must be an integer. '
        'Nothing was applied.',
    'disconnect no edge':
        'operations[0] disconnect: there is no edge from "plan" to '
        '"ghost". Nothing was applied.',
    'disconnect no edge with output':
        'operations[0] disconnect: there is no edge from "plan" to '
        '"review" with output "bad". Nothing was applied.',
    'disconnect output not a string':
        'operations[0] disconnect: output must be a string. Nothing '
        'was applied.',
    'set_entry unknown node':
        'operations[0] set_entry: node "ghost" does not exist. '
        'Nothing was applied.',
    'set_meta nothing to change':
        'operations[0] set_meta: pass name or description. Nothing '
        'was applied.',
    'set_meta blank name':
        'operations[0] set_meta: name must be a non-blank string. '
        'Nothing was applied.',
    'set_meta description not a string':
        'operations[0] set_meta: description must be a string. '
        'Nothing was applied.',
  };
  final invalidOps = <String, List<Object?>>{
    'element not an object': [3],
    'missing op': [{}],
    'unknown op lists the operations': [
      {'op': 'wat'},
    ],
    'add_node id not a string': [
      {'op': 'add_node', 'id': 1},
    ],
    'add_node bad id pattern': [
      {'op': 'add_node', 'id': 'bad-id'},
    ],
    'add_node duplicate id': [
      {'op': 'add_node', 'id': 'plan'},
    ],
    'add_node blank type': [
      {'op': 'add_node', 'id': 'x', 'type': ' '},
    ],
    'add_node blank label': [
      {'op': 'add_node', 'id': 'x', 'type': 'custom', 'label': ' '},
    ],
    'add_node config not an object': [
      {
        'op': 'add_node',
        'id': 'x',
        'type': 'custom',
        'label': 'X',
        'config': 1,
      },
    ],
    'add_node bad position': [
      {
        'op': 'add_node',
        'id': 'x',
        'type': 'custom',
        'label': 'X',
        'position': {'x': 'x', 'y': 1},
      },
    ],
    'update_node unknown node': [
      {'op': 'update_node', 'id': 'ghost', 'label': 'x'},
    ],
    'update_node nothing to change': [
      {'op': 'update_node', 'id': 'plan'},
    ],
    'update_node type to terminal is refused': [
      {'op': 'update_node', 'id': 'plan', 'type': NodeTypeId.terminal},
    ],
    'update_node type from review validator is refused': [
      {'op': 'update_node', 'id': 'review', 'type': NodeTypeId.codex},
    ],
    'update_node type to command is refused': [
      {'op': 'update_node', 'id': 'plan', 'type': NodeTypeId.command},
    ],
    'update_node unknown type is refused': [
      {'op': 'update_node', 'id': 'plan', 'type': 'x'},
    ],
    'update_node non-string type': [
      {'op': 'update_node', 'id': 'plan', 'type': 1},
    ],
    'update_node blank label': [
      {'op': 'update_node', 'id': 'plan', 'label': ' '},
    ],
    'update_node config not an object': [
      {'op': 'update_node', 'id': 'plan', 'config': 1},
    ],
    'remove_node unknown node': [
      {'op': 'remove_node', 'id': 'ghost'},
    ],
    'connect unknown from': [
      {'op': 'connect', 'from': 'ghost', 'to': 'plan', 'output': 'x'},
    ],
    'connect unknown to': [
      {'op': 'connect', 'from': 'plan', 'to': 'ghost', 'output': 'x'},
    ],
    'connect blank output': [
      {'op': 'connect', 'from': 'plan', 'to': 'review', 'output': ' '},
    ],
    'connect output not allowed lists the outputs': [
      {'op': 'connect', 'from': 'review', 'to': 'plan', 'output': 'bad'},
    ],
    'connect maxRetries not an integer': [
      {
        'op': 'connect',
        'from': 'plan',
        'to': 'review',
        'output': 'onFailure',
        'maxRetries': 1.2,
      },
    ],
    'disconnect no edge': [
      {'op': 'disconnect', 'from': 'plan', 'to': 'ghost'},
    ],
    'disconnect no edge with output': [
      {'op': 'disconnect', 'from': 'plan', 'to': 'review', 'output': 'bad'},
    ],
    'disconnect output not a string': [
      {'op': 'disconnect', 'from': 'plan', 'to': 'review', 'output': 1},
    ],
    'set_entry unknown node': [
      {'op': 'set_entry', 'id': 'ghost'},
    ],
    'set_meta nothing to change': [
      {'op': 'set_meta'},
    ],
    'set_meta blank name': [
      {'op': 'set_meta', 'name': ' '},
    ],
    'set_meta description not a string': [
      {'op': 'set_meta', 'description': 1},
    ],
  };
  for (final entry in invalids.entries) {
    test(entry.key, () => expect(error(invalidOps[entry.key]!), entry.value));
  }
}
