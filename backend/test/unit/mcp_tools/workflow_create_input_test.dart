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
}
