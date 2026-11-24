import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';

/// Reads one workflow in compact text or full JSON form (R9, R10).
final class GetWorkflowTool extends ScopedMcpTool {
  /// Creates a [GetWorkflowTool].
  const new({
    required McpScopeResolver scopes,
    required this._workflows,
    required this._formatter,
  }) : super(scopes);

  final WorkflowService _workflows;
  final WorkflowTextFormatter _formatter;

  @override
  String get name => 'get_workflow';

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

    final detailResult = input.optionalString('detail');
    if (detailResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final detail = (detailResult as Success<String?>).value ?? 'compact';
    if (detail != 'compact' && detail != 'full') {
      return const FailureResult(
        ValidationFailure('"detail" must be "compact" or "full".'),
      );
    }

    final wfResult = await _workflows.getWorkflow(
      id,
      workspaceId: scope.workspaceId,
    );
    return switch (wfResult) {
      FailureResult(failure: NotFoundFailure()) => FailureResult(
        NotFoundFailure(
          'Workflow "$id" not found in ${scope.label}. Call list_workflows to '
          'see the ids, or pass workspace.',
        ),
      ),
      FailureResult(:final failure) => FailureResult(failure),
      Success(value: final response) => Success(
        detail == 'full'
            ? jsonEncode(response.toJson())
            : _formatter.workflow(response),
      ),
    };
  }
}
