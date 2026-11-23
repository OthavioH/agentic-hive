import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/create_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_patcher.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Applies patch operations to a workflow in the resolved scope (#110).
final class EditWorkflowTool extends ScopedMcpTool {
  /// Creates a tool with its workflow services and patcher.
  const new({
    required McpScopeResolver scopes,
    required this.workflows,
    required this.patcher,
    required this.formatter,
    required this.events,
  }) : super(scopes);

  /// Workflow persistence and validation service.
  final WorkflowService workflows;

  /// Applies operations on an in-memory copy.
  final WorkflowPatcher patcher;

  /// MCP response formatter.
  final WorkflowTextFormatter formatter;

  /// Workflow change publisher.
  final WorkflowEvents events;

  @override
  String get name => 'edit_workflow';

  /// Formats the stale-revision message (S1).
  static String staleMessage(String id, String sent, String current) =>
      'Workflow "$id" changed since you read it (you sent revision $sent, '
      'it is now $current). Call get_workflow to read it again, then send '
      'your operations again. Nothing was changed.';

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
    final revisionResult = input.requiredString(
      'revision',
      missingMessage:
          'Missing "revision": pass the revision from your last get_workflow '
          'or list_workflows.',
    );
    if (revisionResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final revision = (revisionResult as Success<String>).value;
    final operations = input.arguments['operations'];
    if (operations is! List || operations.isEmpty) {
      return const FailureResult(
        ValidationFailure(
          '"operations" must be a non-empty list of operation objects.',
        ),
      );
    }
    final loaded = await workflows.getWorkflow(
      id,
      workspaceId: scope.workspaceId,
    );
    if (loaded case FailureResult(failure: NotFoundFailure())) {
      return FailureResult(_notFound(id, scope));
    }
    if (loaded case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final response = (loaded as Success<WorkflowResponse>).value;
    final current = response.revision ?? workflowRevision(response.workflow);
    if (current != revision) {
      return FailureResult(
        StaleRevisionFailure(
          staleMessage(id, revision, current),
          currentRevision: current,
        ),
      );
    }
    final patched = patcher.apply(
      response.workflow,
      List<Object?>.from(operations),
    );
    if (patched case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final patch = (patched as Success<WorkflowPatch>).value;
    final saved = await workflows.updateWorkflow(
      id,
      UpdateWorkflowRequest(
        name: patch.name,
        description: patch.description,
        nodes: patch.nodes,
        edges: patch.edges,
        entryNodeId: patch.entryNodeId,
        schemaVersion: response.workflow.schemaVersion,
        revision: revision,
      ),
      workspaceId: scope.workspaceId,
    );
    return switch (saved) {
      FailureResult(failure: StaleRevisionFailure(:final currentRevision)) =>
        FailureResult(
          StaleRevisionFailure(
            staleMessage(id, revision, currentRevision),
            currentRevision: currentRevision,
          ),
        ),
      FailureResult(failure: NotFoundFailure()) => FailureResult(
        _notFound(id, scope),
      ),
      FailureResult(failure: WorkflowDeletingFailure(:final operationId)) =>
        FailureResult(_deleting(id, operationId)),
      FailureResult(:final failure) => FailureResult(failure),
      Success(value: final result) => _success(revision, patch, result),
    };
  }

  /// The text for a save refused while the workflow is being deleted (#119).
  WorkflowDeletingFailure _deleting(String id, String operationId) =>
      WorkflowDeletingFailure(
        'Workflow "$id" is being deleted (operation $operationId), so it '
        'cannot be edited. Nothing was changed. Do not retry: the deletion is '
        'running and will finish on its own.',
        operationId: operationId,
      );

  NotFoundFailure _notFound(String id, McpScope scope) => NotFoundFailure(
    'Workflow "$id" not found in ${scope.label}. Call list_workflows to see '
    'the ids, or pass workspace.',
  );

  Success<String> _success(
    String revision,
    WorkflowPatch patch,
    WorkflowResponse response,
  ) {
    events.workflowChanged(
      WorkflowChangeKind.updated,
      response.workflow.id,
      workspaceId: response.workspaceId,
      workflow: workflowSummaryOf(response),
    );
    final suffix = response.validation.isValid
        ? ''
        : '\n${CreateWorkflowTool.draftLine}';
    return Success(
      'Edited workflow ${response.workflow.id} "${response.workflow.name}" '
      'revision ${response.revision} (was $revision)\n'
      'Applied ${patch.operationCount} operations: ${patch.tally.describe()}.\n'
      'Now ${response.workflow.nodes.length} nodes, '
      '${response.workflow.edges.length} edges, entry '
      '${response.workflow.entryNodeId ?? 'none'}\n'
      '${formatter.validation(response.validation)}$suffix',
    );
  }
}
