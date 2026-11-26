import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_service.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/building_blocks_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists node types and the agents of the resolved scope (#108).
final class ListBuildingBlocksTool extends ScopedMcpTool {
  /// Creates a [ListBuildingBlocksTool]. `nodeTypes` is read on every call so
  /// node types registered later appear without changing the tool.
  const new({
    required McpScopeResolver scopes,
    required this._nodeTypes,
    required this._agents,
    required this._formatter,
  }) : super(scopes);

  final List<NodeDescriptor> Function() _nodeTypes;
  final AgentService _agents;
  final BuildingBlocksTextFormatter _formatter;

  @override
  String get name => 'list_building_blocks';

  @override
  Future<Result<String>> runInScope(McpScope scope, McpToolInput input) async {
    final listed = await _agents.list(scope: scope.definitionScope);
    return listed.map((all) {
      final usable = all.where((a) => a.parseError == null).toList();
      final workspaceIds = {
        for (final a in usable)
          if (a.scope is WorkspaceScope) a.id,
      };
      final visible = usable
          .where((a) => !a.overridden)
          .where(
            (a) => a.scope is WorkspaceScope || !workspaceIds.contains(a.id),
          )
          .toList(growable: false);
      return _formatter.format(
        nodeTypes: _nodeTypes(),
        agents: visible,
        brokenAgents: all.length - usable.length,
      );
    });
  }
}
