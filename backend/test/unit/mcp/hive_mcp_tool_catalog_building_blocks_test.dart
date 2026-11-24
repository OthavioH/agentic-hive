import 'package:agentic_hive_backend/src/mcp/hive_mcp_tool_catalog.dart';
import 'package:dart_mcp/server.dart';
import 'package:test/test.dart';

void main() {
  final tool = HiveMcpToolCatalog.backendTools.singleWhere(
    (item) => item.name == 'list_building_blocks',
  );

  test('T-C1 list_building_blocks is the last backend tool', () {
    expect(HiveMcpToolCatalog.backendTools.last.name, 'list_building_blocks');
  });

  test('T-C2 takes only an optional workspace', () {
    expect(tool.inputSchema.properties!.keys, ['workspace']);
    expect(tool.inputSchema.required, anyOf(isNull, isEmpty));
    expect(tool.inputSchema.additionalProperties, isFalse);
    expect(tool.inputSchema.validate(<String, Object?>{}), isEmpty);
    expect(tool.inputSchema.validate({'workspace': 'global'}), isEmpty);
    expect(tool.inputSchema.validate({'foo': 1}), isNotEmpty);
  });
}
