import 'package:agentic_hive_backend/src/mcp/hive_mcp_tool_catalog.dart';
import 'package:dart_mcp/server.dart';
import 'package:test/test.dart';

void main() {
  final tool = HiveMcpToolCatalog.backendTools.singleWhere(
    (item) => item.name == 'edit_workflow',
  );
  test('edit_workflow requires id, revision and operations', () {
    expect(tool.inputSchema.required, ['id', 'revision', 'operations']);
  });
  test('edit_workflow rejects unknown top-level keys', () {
    expect(tool.inputSchema.additionalProperties, isFalse);
  });
  test('the example arguments pass the schema', () {
    expect(
      tool.inputSchema.validate({
        'id': 'review-loop',
        'revision': '0123456789abcdef',
        'operations': [
          {
            'op': 'add_node',
            'id': 'fix_tests',
            'type': 'harness.claude_code',
            'label': 'Fix tests',
          },
          {
            'op': 'connect',
            'from': 'review',
            'to': 'fix_tests',
            'output': 'changesRequested',
            'maxRetries': 2,
          },
          {'op': 'disconnect', 'from': 'review', 'to': 'plan'},
          {'op': 'update_node', 'id': 'plan', 'label': 'Plan the change'},
          {'op': 'update_node', 'id': 'plan', 'type': 'harness.codex'},
          {
            'op': 'update_node',
            'id': 'plan',
            'config': {
              'fallback': [
                {'harness': 'harness.codex', 'model': 'gpt-5'},
              ],
            },
          },
          {'op': 'set_meta', 'description': 'Plans, reviews and fixes.'},
        ],
        'workspace': 'global',
      }),
      isEmpty,
    );
  });
  test('empty operations fail the schema', () {
    expect(
      tool.inputSchema.validate({
        'id': 'x',
        'revision': 'x',
        'operations': <Object?>[],
      }),
      isNotEmpty,
    );
  });
  test('an unknown op fails the schema', () {
    expect(
      tool.inputSchema.validate({
        'id': 'x',
        'revision': 'x',
        'operations': [
          {'op': 'unknown'},
        ],
      }),
      isNotEmpty,
    );
  });
}
