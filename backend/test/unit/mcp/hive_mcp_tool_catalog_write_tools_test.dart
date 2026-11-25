import 'package:agentic_hive_backend/src/mcp/hive_mcp_tool_catalog.dart';
import 'package:dart_mcp/server.dart';
import 'package:test/test.dart';

void main() {
  final tools = HiveMcpToolCatalog.backendTools;

  test('create_workflow requires name, nodes, edges and entryNodeId', () {
    final tool = tools.singleWhere((item) => item.name == 'create_workflow');
    expect(
      tool.inputSchema.required,
      containsAll(['name', 'nodes', 'edges', 'entryNodeId']),
    );
  });

  test('duplicate_workflow requires id', () {
    final tool = tools.singleWhere((item) => item.name == 'duplicate_workflow');
    expect(tool.inputSchema.required, ['id']);
  });

  test('both reject unknown top-level keys', () {
    for (final name in ['create_workflow', 'duplicate_workflow']) {
      final tool = tools.singleWhere((item) => item.name == name);
      expect(tool.inputSchema.additionalProperties, isFalse);
    }
  });

  test('a valid create input passes the schema', () {
    final tool = tools.singleWhere((item) => item.name == 'create_workflow');
    expect(
      tool.inputSchema.validate({
        'name': 'Review loop',
        'nodes': [
          {'id': 'plan', 'type': 'harness.claude_code', 'label': 'Plan'},
          {
            'id': 'review',
            'type': 'validator.review',
            'label': 'Review',
            'position': {'x': 900, 'y': 400},
          },
        ],
        'edges': [
          {'from': 'plan', 'to': 'review', 'output': 'onSuccess'},
          {
            'from': 'review',
            'to': 'plan',
            'output': 'changesRequested',
            'maxRetries': 2,
          },
        ],
        'entryNodeId': 'plan',
        'workspace': 'global',
      }),
      isEmpty,
    );
  });

  test('a create input without positions passes the schema', () {
    final tool = tools.singleWhere((item) => item.name == 'create_workflow');
    expect(
      tool.inputSchema.validate({
        'name': 'One',
        'nodes': [
          {'id': 'n', 'type': 'unknown', 'label': 'Node'},
        ],
        'edges': <Object?>[],
        'entryNodeId': 'n',
      }),
      isEmpty,
    );
  });

  test('a create input missing nodes fails the schema', () {
    final tool = tools.singleWhere((item) => item.name == 'create_workflow');
    expect(
      tool.inputSchema.validate({
        'name': 'One',
        'edges': <Object?>[],
        'entryNodeId': 'n',
      }),
      isNotEmpty,
    );
  });
}
