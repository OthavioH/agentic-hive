import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Decodes finished deletion events; returns null for other or malformed data.
WorkflowDeletionFinished? decodeWorkflowDeletionEvent(WsEnvelope envelope) {
  try {
    return switch (envelope.type) {
      WsMessageType.workflowDeleted => _deleted(envelope.payload),
      WsMessageType.workflowDeleteFailed => _failed(envelope.payload),
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

/// Decodes a `workflow.delete.progress` envelope; null for other or malformed
/// data.
WorkflowDeletionStatus? decodeWorkflowDeletionProgress(WsEnvelope envelope) {
  if (envelope.type != WsMessageType.workflowDeleteProgress) return null;
  try {
    return WorkflowDeletionStatus.fromJson(envelope.payload);
  } on FormatException {
    return null;
  }
}

WorkflowDeletionFinished _deleted(JsonMap payload) {
  final deleted = WorkflowDeletedPayload.fromJson(payload);
  return WorkflowDeletionFinished(
    operationId: deleted.operationId,
    workflowId: deleted.workflowId,
    workspaceId: deleted.workspaceId,
    deletedRuns: deleted.deletedRuns,
    orphanedRuns: deleted.orphanedRuns,
  );
}

WorkflowDeletionFinished _failed(JsonMap payload) {
  final failed = WorkflowDeleteFailedPayload.fromJson(payload);
  return WorkflowDeletionFinished(
    operationId: failed.operationId,
    workflowId: failed.workflowId,
    workspaceId: failed.workspaceId,
    failure: BackendFailure(failed.message, code: failed.code),
    deletedRuns: failed.deletedRuns,
    orphanedRuns: failed.orphanedRuns,
  );
}
