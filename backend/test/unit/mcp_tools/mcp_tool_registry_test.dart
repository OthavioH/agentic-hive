import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool_registry.dart';
import 'package:test/test.dart';

final class _StubTool extends McpTool {
  const new(this.name);

  @override
  final String name;

  @override
  Future<Result<String>> call(McpToolInput input) async =>
      Success('called $name');
}

void main() {
  test('finds tools by name', () {
    final registry = McpToolRegistry([
      const _StubTool('alpha'),
      const _StubTool('beta'),
    ]);
    expect(registry.byName('alpha')?.name, 'alpha');
    expect(registry.byName('beta')?.name, 'beta');
    expect(registry.names, ['alpha', 'beta']);
  });

  test('unknown name gives null', () {
    final registry = McpToolRegistry([const _StubTool('alpha')]);
    expect(registry.byName('missing'), isNull);
  });

  test('duplicate names throw ArgumentError', () {
    expect(
      () => McpToolRegistry([const _StubTool('dup'), const _StubTool('dup')]),
      throwsArgumentError,
    );
  });
}
