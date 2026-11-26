import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_create_input.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Creates a workflow from structured JSON in the resolved scope.
final class CreateWorkflowTool extends ScopedMcpTool {
  /// Creates a tool with the required workflow services.
  const new({
    required McpScopeResolver scopes,
    required this.workflows,
    required this.parser,
    required this.formatter,
    required this.events,
  }) : super(scopes);

  /// Workflow persistence and validation service.
  final WorkflowService workflows;

  /// Structured input parser.
  final WorkflowCreateInputParser parser;

  /// MCP response formatter.
  final WorkflowTextFormatter formatter;

  /// Workflow change publisher.
  final WorkflowEvents events;

  @override
  String get name => 'create_workflow';

  /// Draft notice appended when validation reports errors.
  static const draftLine =
      'Saved as a draft: fix the errors with edit_workflow before running it.';

  @override
  Future<Result<String>> runInScope(McpScope scope, McpToolInput input) async {
    final parsed = parser.parse(input);
    if (parsed case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final draft = (parsed as Success<WorkflowCreateDraft>).value;
    final created = await workflows.createWorkflow(
      CreateWorkflowRequest(
        name: draft.name,
        description: draft.description,
        nodes: draft.nodes,
        edges: draft.edges,
        entryNodeId: draft.entryNodeId,
        workspaceId: scope.workspaceId,
      ),
    );
    if (created case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final response = (created as Success<WorkflowResponse>).value;
    events.workflowChanged(
      WorkflowChangeKind.created,
      response.workflow.id,
      scope: response.scope,
      workflow: workflowSummaryOf(response),
    );
    final suffix = response.validation.isValid ? '' : '\n$draftLine';
    return Success(
      'Created workflow ${response.workflow.id} "${response.workflow.name}" '
      'revision ${response.revision}\n'
      '${draft.nodes.length} nodes (${draft.autoPlaced} auto-placed), '
      '${draft.edges.length} edges\n'
      '${formatter.validation(response.validation)}$suffix',
    );
  }
}
