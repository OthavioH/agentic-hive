import 'package:agentic_hive_backend/src/mcp/hive_mcp_tool_catalog.dart';
import 'package:dart_mcp/server.dart';
import 'package:test/test.dart';

void main() {
  final tools = HiveMcpToolCatalog.backendTools;
  final tool = tools.singleWhere((item) => item.name == 'delete_workflow');

  test('delete_workflow requires id and revision', () {
    expect(tool.inputSchema.required, ['id', 'revision']);
  });

  test('delete_workflow has no force parameter', () {
    expect(tool.inputSchema.properties!.keys, ['id', 'revision', 'workspace']);
    expect(tool.inputSchema.properties!.containsKey('force'), isFalse);
  });

  test('delete_workflow rejects unknown keys such as force', () {
    expect(tool.inputSchema.additionalProperties, isFalse);
    expect(
      tool.inputSchema.validate(<String, Object?>{
        'id': 'a',
        'revision': 'r',
        'force': true,
      }),
      isNotEmpty,
    );
  });

  test('a valid delete input passes the schema', () {
    expect(
      tool.inputSchema.validate(<String, Object?>{
        'id': 'a',
        'revision': 'r',
        'workspace': 'global',
      }),
      isEmpty,
    );
  });

  test('delete_workflow comes right before list_building_blocks', () {
    final deleteIndex = tools.indexWhere(
      (item) => item.name == 'delete_workflow',
    );
    final blocksIndex = tools.indexWhere(
      (item) => item.name == 'list_building_blocks',
    );
    expect(deleteIndex + 1, blocksIndex);
  });
}
