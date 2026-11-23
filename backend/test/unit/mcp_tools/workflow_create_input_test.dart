import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_create_input.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  const parser = WorkflowCreateInputParser(describe: NodeDescriptors.of);

  McpToolInput input(JsonMap arguments) => McpToolInput(arguments: arguments);

  test('node id with a hyphen is refused', () {
    final result = parser.parse(
      input({
        'name': 'Review',
        'nodes': [
          {'id': 'bad-id', 'type': 'unknown', 'label': 'Bad'},
        ],
        'edges': [],
        'entryNodeId': 'bad-id',
      }),
    );

    expect(result, isA<FailureResult<WorkflowCreateDraft>>());
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(result.failureOrNull!.message, contains('bad-id'));
  });

  test('accepts editor style ids and auto-places missing positions', () {
    final result = parser.parse(
      input({
        'name': ' Review loop ',
        'description': '  ',
        'nodes': [
          {'id': 'node_3', 'type': 'unknown', 'label': ' Plan '},
        ],
        'edges': [],
        'entryNodeId': 'node_3',
      }),
    );

    final draft = (result as Success<WorkflowCreateDraft>).value;
    expect(draft.name, 'Review loop');
    expect(draft.description, isNull);
    expect(draft.autoPlaced, 1);
    expect(draft.nodes.single.position, const WorkflowPosition(x: 120, y: 120));
  });

  test('edge ids are generated in input order', () {
    final result = parser.parse(
      input({
        'name': 'Review',
        'nodes': [
          {'id': 'a', 'type': 'unknown', 'label': 'A'},
          {'id': 'b', 'type': 'unknown', 'label': 'B'},
        ],
        'edges': [
          {'from': 'a', 'to': 'b', 'output': 'anything'},
          {'from': 'b', 'to': 'a', 'output': 'anything'},
        ],
        'entryNodeId': 'a',
      }),
    );

    final draft = (result as Success<WorkflowCreateDraft>).value;
    expect(draft.edges.map((edge) => edge.id), ['edge_1', 'edge_2']);
  });

  test(
    'missing name is rejected',
    () => _reject({'nodes': [], 'edges': [], 'entryNodeId': 'a'}, 'name'),
  );
  test(
    'non-string name is rejected',
    () => _reject({
      'name': 3,
      'nodes': [],
      'edges': [],
      'entryNodeId': 'a',
    }, 'name'),
  );
  test(
    'non-string description is rejected',
    () => _reject({
      'name': 'x',
      'description': 1,
      'nodes': [],
      'edges': [],
      'entryNodeId': 'a',
    }, 'description'),
  );
  test(
    'nodes not a list is rejected',
    () => _reject({
      'name': 'x',
      'nodes': 3,
      'edges': [],
      'entryNodeId': 'a',
    }, 'nodes'),
  );
  test(
    'node not an object is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [3],
      'edges': [],
      'entryNodeId': 'a',
    }, 'nodes[0]'),
  );
  test(
    'node id not a string is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [
        {'id': 1},
      ],
      'edges': [],
      'entryNodeId': 'a',
    }, 'nodes[0].id'),
  );
  test(
    'node id with uppercase is refused',
    () => _reject({
      'name': 'x',
      'nodes': [_node('Node')],
      'edges': [],
      'entryNodeId': 'Node',
    }, 'Node'),
  );
  test(
    'node id longer than 32 is refused',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a${'b' * 32}')],
      'edges': [],
      'entryNodeId': 'a${'b' * 32}',
    }, '32'),
  );
  test(
    'duplicate node id names both indexes',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a'), _node('a')],
      'edges': [],
      'entryNodeId': 'a',
    }, 'nodes[0]'),
  );
  test(
    'blank type is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a', type: ' ')],
      'edges': [],
      'entryNodeId': 'a',
    }, 'type'),
  );
  test(
    'blank label is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a', label: ' ')],
      'edges': [],
      'entryNodeId': 'a',
    }, 'label'),
  );
  test(
    'config not an object is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a', config: 1)],
      'edges': [],
      'entryNodeId': 'a',
    }, 'config'),
  );
  test(
    'position missing y is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [
        _node('a', position: {'x': 1}),
      ],
      'edges': [],
      'entryNodeId': 'a',
    }, 'position'),
  );
  test(
    'edges not a list is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a')],
      'edges': 1,
      'entryNodeId': 'a',
    }, 'edges'),
  );
  test(
    'edge not an object is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a')],
      'edges': [1],
      'entryNodeId': 'a',
    }, 'edges[0]'),
  );
  test(
    'edge from unknown node is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a')],
      'edges': [
        {'from': 'z', 'to': 'a', 'output': 'x'},
      ],
      'entryNodeId': 'a',
    }, '"z"'),
  );
  test(
    'edge to unknown node is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a')],
      'edges': [
        {'from': 'a', 'to': 'z', 'output': 'x'},
      ],
      'entryNodeId': 'a',
    }, '"z"'),
  );
  test(
    'blank output is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a')],
      'edges': [
        {'from': 'a', 'to': 'a', 'output': ' '},
      ],
      'entryNodeId': 'a',
    }, 'output'),
  );
  test(
    'output not allowed for a known type lists the outputs',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a', type: 'harness.claude_code')],
      'edges': [
        {'from': 'a', 'to': 'a', 'output': 'wrong'},
      ],
      'entryNodeId': 'a',
    }, 'onSuccess'),
  );
  test(
    'maxRetries not an integer is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a')],
      'edges': [
        {'from': 'a', 'to': 'a', 'output': 'x', 'maxRetries': 1.5},
      ],
      'entryNodeId': 'a',
    }, 'maxRetries'),
  );
  test(
    'missing entryNodeId is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a')],
      'edges': [],
    }, 'entryNodeId'),
  );
  test(
    'unknown entryNodeId is rejected',
    () => _reject({
      'name': 'x',
      'nodes': [_node('a')],
      'edges': [],
      'entryNodeId': 'z',
    }, '"z"'),
  );
  test(
    'labels, name and description are trimmed; blank description is null',
    () {
      final result = parser.parse(
        input({
          'name': ' x ',
          'description': ' ',
          'nodes': [_node('a', label: ' A ')],
          'edges': [],
          'entryNodeId': 'a',
        }),
      ) as Success<WorkflowCreateDraft>;
      expect(result.value.name, 'x');
      expect(result.value.description, isNull);
      expect(result.value.nodes.single.label, 'A');
    },
  );

  test('unknown type is accepted and keeps any output', () {
    final result = parser.parse(
      input({
        'name': 'x',
        'nodes': [_node('a', type: 'custom')],
        'edges': [
          {'from': 'a', 'to': 'a', 'output': 'custom-output'},
        ],
        'entryNodeId': 'a',
      }),
    );
    expect(result, isA<Success<WorkflowCreateDraft>>());
  });

  test('known type config is merged over defaults', () {
    final result = parser.parse(
      input({
        'name': 'x',
        'nodes': [
          _node(
            'a',
            type: 'harness.claude_code',
            config: {'agentId': 'planner'},
          ),
        ],
        'edges': [],
        'entryNodeId': 'a',
      }),
    ) as Success<WorkflowCreateDraft>;
    expect(
      result.value.nodes.single.config,
      containsPair('agentId', 'planner'),
    );
    expect(
      result.value.nodes.single.config.keys,
      containsAll(
        NodeDescriptors.of('harness.claude_code')!.defaultConfig().keys,
      ),
    );
  });

  test('nodes without position are auto-placed and counted', () {
    final result = parser.parse(
      input({
        'name': 'x',
        'nodes': [_node('a')],
        'edges': [],
        'entryNodeId': 'a',
      }),
    ) as Success<WorkflowCreateDraft>;
    expect(result.value.autoPlaced, 1);
    expect(
      result.value.nodes.single.position,
      const WorkflowPosition(x: 120, y: 120),
    );
  });

  test(
    'the first problem wins',
    () => _reject({
      'name': 3,
      'nodes': [1],
      'edges': [],
      'entryNodeId': 'a',
    }, 'name'),
  );
}

Map<String, Object?> _node(
  String id, {
  String type = 'unknown',
  String label = 'A',
  Object? config,
  Map<String, Object?>? position,
}) => {
  'id': id,
  'type': type,
  'label': label,
  'config': ?config,
  'position': ?position,
};

void _reject(Map<String, Object?> arguments, String message) {
  final result = const WorkflowCreateInputParser(describe: NodeDescriptors.of)
      .parse(McpToolInput(arguments: arguments));
  expect(result, isA<FailureResult<WorkflowCreateDraft>>());
  expect(result.failureOrNull, isA<ValidationFailure>());
  expect(result.failureOrNull!.message, contains(message));
}

McpToolInput input(JsonMap arguments) => McpToolInput(arguments: arguments);
