import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists the Global scope and every registered workspace with workflow counts
/// (R7).
final class ListWorkspacesTool extends McpTool {
  /// Creates a [ListWorkspacesTool].
  const new({
    required this._workspaces,
    required this._globalWorkflows,
    required this._workspaceWorkflows,
    required this._formatter,
  });

  final WorkspaceRepository _workspaces;
  final WorkflowRepository _globalWorkflows;
  final WorkspaceWorkflowRepository _workspaceWorkflows;
  final WorkflowTextFormatter _formatter;

  @override
  String get name => 'list_workspaces';

  @override
  Future<Result<String>> call(McpToolInput input) async {
    final globalResult = await _globalWorkflows.listAll();
    if (globalResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final globalCount = (globalResult as Success<List<Workflow>>).value.length;

    final wsResult = await _workspaces.list();
    if (wsResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final list = (wsResult as Success<List<Workspace>>).value;

    final items = <({Workspace workspace, int? count})>[];
    for (final ws in list) {
      final countResult = await _workspaceWorkflows.listAll(ws.rootPath);
      final count = switch (countResult) {
        Success(value: final workflows) => workflows.length,
        FailureResult() => null,
      };
      items.add((workspace: ws, count: count));
    }

    return Success(
      _formatter.workspaces(globalCount: globalCount, items: items),
    );
  }
}
