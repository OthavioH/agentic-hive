import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// A workflow deletion operation finished; [failure] is null on success.
final class WorkflowDeletionFinished {
  /// Creates a completion event.
  const new({required this.operationId, this.failure});

  /// Operation identifier.
  final String operationId;

  /// Operation failure, when it failed.
  final Failure? failure;
}

/// Live feed of finished workflow deletions from the backend WebSocket.
abstract interface class WorkflowDeletionEventsSource {
  /// Finished operations.
  Stream<WorkflowDeletionFinished> get finished;
}

/// Decodes finished deletion events; returns null for other or malformed data.
WorkflowDeletionFinished? decodeWorkflowDeletionEvent(WsEnvelope envelope) {
  try {
    return switch (envelope.type) {
      WsMessageType.workflowDeleted => WorkflowDeletionFinished(
        operationId: WorkflowDeletedPayload.fromJson(envelope.payload)
            .operationId,
      ),
      WsMessageType.workflowDeleteFailed => _failed(envelope.payload),
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

WorkflowDeletionFinished _failed(JsonMap payload) {
  final failed = WorkflowDeleteFailedPayload.fromJson(payload);
  return WorkflowDeletionFinished(
    operationId: failed.operationId,
    failure: BackendFailure(failed.message, code: failed.code),
  );
}
