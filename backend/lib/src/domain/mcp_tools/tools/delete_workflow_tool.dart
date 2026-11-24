import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Deletes a workflow and its runs without forcing (#111, ADR 0027).
final class DeleteWorkflowTool extends ScopedMcpTool {
  /// Creates a tool that waits up to [maxWait] for each deletion, polling
  /// every [pollInterval].
  const new({
    required McpScopeResolver scopes,
    required this.workflows,
    required this.events,
    this.maxWait = defaultMaxWait,
    this.pollInterval = defaultPollInterval,
  }) : super(scopes);

  /// How long one call waits for its deletion before answering in progress.
  static const defaultMaxWait = Duration(seconds: 20);

  /// Time between two status reads while waiting.
  static const defaultPollInterval = Duration(milliseconds: 500);

  /// Workflow deletion and status service.
  final WorkflowService workflows;

  /// Workflow change publisher.
  final WorkflowEvents events;

  /// Longest accumulated wait for one call.
  final Duration maxWait;

  /// Time between two status reads.
  final Duration pollInterval;

  @override
  String get name => 'delete_workflow';

  /// Formats the stale-revision message (T-STALE).
  static String staleMessage(String id, String sent, String current) =>
      'Workflow "$id" changed since you read it (you sent revision $sent, it '
      'is now $current). Call get_workflow to read it again, check it is still '
      'the one to delete, then call delete_workflow with the new revision. '
      'Nothing was deleted.';

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
    final accepted = await workflows.deleteWorkflow(
      id,
      workspaceId: scope.workspaceId,
      expectedRevision: revision,
    );
    return switch (accepted) {
      FailureResult(failure: NotFoundFailure()) => Success(
        _alreadyDeleted(id, scope),
      ),
      FailureResult(failure: StaleRevisionFailure(:final currentRevision)) =>
        FailureResult(
          StaleRevisionFailure(
            staleMessage(id, revision, currentRevision),
            currentRevision: currentRevision,
          ),
        ),
      FailureResult(failure: WorkflowHasActiveRunsFailure(:final activeRuns)) =>
        FailureResult(
          WorkflowHasActiveRunsFailure(
            _active(id, activeRuns),
            activeRuns: activeRuns,
          ),
        ),
      FailureResult(:final failure) => FailureResult(failure),
      Success(value: final started) => await _wait(
        id,
        started.operationId,
        scope,
      ),
    };
  }

  /// Polls the operation until it finishes or [maxWait] elapses.
  Future<Result<String>> _wait(
    String id,
    String operationId,
    McpScope scope,
  ) async {
    _announceWhenDeleted(id, operationId, scope);
    var waited = Duration.zero;
    while (true) {
      final status = workflows.getDeletion(operationId);
      if (status case FailureResult()) {
        return Success(_gone(id, operationId));
      }
      final operation = (status as Success<WorkflowDeletionOperation>).value;
      if (operation.isFinished) {
        return _finished(id, operation);
      }
      if (waited >= maxWait) {
        return Success(_inProgress(id, operationId));
      }
      await Future<void>.delayed(pollInterval);
      waited += pollInterval;
    }
  }

  /// Publishes the workflow change when the operation finishes deleted, also
  /// after this call answered in progress (R9).
  void _announceWhenDeleted(String id, String operationId, McpScope scope) {
    final finished = workflows.whenDeletionFinished(operationId);
    if (finished == null) return;
    unawaited(
      finished.then((operation) {
        if (operation.outcome == WorkflowDeletionOutcome.deleted) {
          events.workflowChanged(
            WorkflowChangeKind.deleted,
            id,
            workspaceId: scope.workspaceId,
          );
        }
      }),
    );
  }

  Result<String> _finished(String id, WorkflowDeletionOperation operation) {
    if (operation.outcome != WorkflowDeletionOutcome.deleted) {
      return FailureResult(
        ConflictFailure(
          'Deleting workflow "$id" failed (operation ${operation.id}) after '
          'deleting ${_runs(operation.runsDeleted)}. The workflow was not '
          'deleted. Tell the user to check the Workflows page in Agentic Hive '
          'before you try again.',
        ),
      );
    }
    final orphans = operation.orphanedRuns;
    final orphanLine = orphans.isEmpty
        ? ''
        : '\nKept ${_runs(orphans.length)} that could not be confirmed as '
              'stopped: ${orphans.join(', ')}. The user can retry their cancel '
              'in Agentic Hive.';
    return Success(
      'Deleted workflow "$id" and ${_runs(operation.runsDeleted)} '
      '(operation ${operation.id}).$orphanLine',
    );
  }

  String _alreadyDeleted(String id, McpScope scope) =>
      'Workflow "$id" is already deleted: it is not in ${scope.label}. Nothing '
      'to do. If it should exist, check the id and workspace with '
      'list_workflows.';

  String _active(String id, Map<String, RunStatus> activeRuns) {
    final count = activeRuns.length;
    final entries = activeRuns.entries
        .map((entry) => '${entry.key} (${entry.value.name})')
        .join(', ');
    final noun = count == 1 ? 'run' : 'runs';
    return 'Workflow "$id" has $count active $noun: $entries. Ask the user to '
        'stop them in Agentic Hive, then call delete_workflow again. Nothing '
        'was deleted.';
  }

  String _inProgress(String id, String operationId) =>
      'Workflow "$id": deletion in progress (operation $operationId). It '
      'finishes on its own; call delete_workflow again with the same id to '
      'wait for the result.';

  String _gone(String id, String operationId) =>
      'Workflow "$id": deletion finished (operation $operationId) but its '
      'result is no longer available. Call list_workflows to confirm it is '
      'gone.';

  static String _runs(int count) => count == 1 ? '1 run' : '$count runs';
}
