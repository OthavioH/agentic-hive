import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/create_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Duplicates a workflow in its resolved scope.
final class DuplicateWorkflowTool extends ScopedMcpTool {
  /// Creates a tool with the required workflow services.
  const new({
    required McpScopeResolver scopes,
    required this.workflows,
    required this.formatter,
    required this.events,
  }) : super(scopes);

  /// Workflow persistence and validation service.
  final WorkflowService workflows;

  /// MCP response formatter.
  final WorkflowTextFormatter formatter;

  /// Workflow change publisher.
  final WorkflowEvents events;

  @override
  String get name => 'duplicate_workflow';

  @override
  Future<Result<String>> runInScope(McpScope scope, McpToolInput input) async {
    final idResult = input.requiredString(
      'id',
      missingMessage: 'Missing "id": pass a workflow id from list_workflows.',
    );
    if (idResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final id = (idResult as Success<String>).value;
    final nameResult = input.optionalString('name');
    if (nameResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final name = (nameResult as Success<String?>).value;
    final duplicated = await workflows.duplicateWorkflow(
      id,
      name: name,
      workspaceId: scope.workspaceId,
    );
    return switch (duplicated) {
      FailureResult(failure: NotFoundFailure()) => FailureResult(
        NotFoundFailure(
          'Workflow "$id" not found in ${scope.label}. Call list_workflows to '
          'see the ids, or pass workspace.',
        ),
      ),
      FailureResult(failure: WorkflowDeletingFailure(:final operationId)) =>
        FailureResult(
          WorkflowDeletingFailure(
            'Workflow "$id" is being deleted (operation $operationId), so it '
            'cannot be duplicated. Nothing was created. Do not retry: the '
            'deletion is running and will finish on its own.',
            operationId: operationId,
          ),
        ),
      FailureResult(:final failure) => FailureResult(failure),
      Success(value: final response) => _success(id, response),
    };
  }

  Success<String> _success(String sourceId, WorkflowResponse response) {
    events.workflowChanged(
      WorkflowChangeKind.created,
      response.workflow.id,
      workspaceId: response.workspaceId,
      workflow: workflowSummaryOf(response),
    );
    final suffix = response.validation.isValid
        ? ''
        : '\n${CreateWorkflowTool.draftLine}';
    return Success(
      'Duplicated workflow $sourceId as ${response.workflow.id} '
      '"${response.workflow.name}" revision ${response.revision}\n'
      '${formatter.validation(response.validation)}$suffix',
    );
  }
}
