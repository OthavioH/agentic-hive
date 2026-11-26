import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Converts an operation snapshot to its HTTP and WebSocket status contract.
WorkflowDeletionStatus workflowDeletionStatusOf(WorkflowDeletionOperation op) {
  final error = op.failure == null ? null : mapFailureToHttp(op.failure!).error;
  return WorkflowDeletionStatus(
    operationId: op.id,
    workflowId: op.workflowId,
    workspaceId: op.scope.workspaceIdOrNull,
    phase: op.phase,
    runsToStop: op.runsToStop,
    runsStopped: op.runsStopped,
    runsDeleted: op.runsDeleted,
    orphanedRuns: op.orphanedRuns,
    outcome: op.outcome,
    errorCode: error?.code,
    errorMessage: error?.message,
    startedAt: op.startedAt,
    finishedAt: op.finishedAt,
  );
}

/// Converts a successful operation to its event payload.
WorkflowDeletedPayload workflowDeletedPayloadOf(WorkflowDeletionOperation op) =>
    WorkflowDeletedPayload(
      operationId: op.id,
      workflowId: op.workflowId,
      workspaceId: op.scope.workspaceIdOrNull,
      deletedRuns: op.runsDeleted,
      orphanedRuns: op.orphanedRuns,
    );

/// Converts a failed operation to its event payload.
WorkflowDeleteFailedPayload workflowDeleteFailedPayloadOf(
  WorkflowDeletionOperation op,
) {
  final error = op.failure == null ? null : mapFailureToHttp(op.failure!).error;
  return WorkflowDeleteFailedPayload(
    operationId: op.id,
    workflowId: op.workflowId,
    workspaceId: op.scope.workspaceIdOrNull,
    code: error?.code ?? ApiErrorCode.internalError,
    message: error?.message ?? 'Internal server error.',
    deletedRuns: op.runsDeleted,
    orphanedRuns: op.orphanedRuns,
  );
}
