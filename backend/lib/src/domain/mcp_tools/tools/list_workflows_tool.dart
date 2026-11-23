import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists workflows in the resolved scope (R8).
final class ListWorkflowsTool extends ScopedMcpTool {
  /// Creates a [ListWorkflowsTool].
  const new({
    required McpScopeResolver scopes,
    required this._workflows,
    required this._formatter,
  }) : super(scopes);

  final WorkflowService _workflows;
  final WorkflowTextFormatter _formatter;

  @override
  String get name => 'list_workflows';

  @override
  Future<Result<String>> runInScope(McpScope scope, McpToolInput input) async {
    final result = await _workflows.listWorkflows(
      workspaceId: scope.workspaceId,
    );
    return result.map((list) {
      final filtered = scope.workspaceId == null
          ? list.workflows
          : list.workflows
                .where((item) => item.scope == WorkflowScope.workspace)
                .toList(growable: false);
      final hint = scope.workspaceId == null
          ? 'Pass workspace (id or root path, see list_workspaces) to see a '
                "workspace's workflows."
          : 'Pass workspace=global to see global workflows.';
      return _formatter.summaries(filtered, hint: hint);
    });
  }
}
