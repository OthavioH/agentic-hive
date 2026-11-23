import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';

/// Registry of backend-served [McpTool]s.
final class McpToolRegistry {
  /// Creates a registry from [tools], throwing [ArgumentError] on duplicate
  /// tool names.
  new(List<McpTool> tools) : _tools = _index(tools);

  final Map<String, McpTool> _tools;

  static Map<String, McpTool> _index(List<McpTool> tools) {
    final map = <String, McpTool>{};
    for (final tool in tools) {
      if (map.containsKey(tool.name)) {
        throw ArgumentError('Duplicate MCP tool "${tool.name}".');
      }
      map[tool.name] = tool;
    }
    return Map<String, McpTool>.unmodifiable(map);
  }

  /// Looks up a tool by [name], or returns `null` if unknown.
  McpTool? byName(String name) => _tools[name];

  /// All registered tool names in registration order.
  List<String> get names => _tools.keys.toList(growable: false);
}
