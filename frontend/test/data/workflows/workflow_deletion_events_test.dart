import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes workflow.deleted as a successful finish', () {
    final envelope = WsEnvelope(
      type: WsMessageType.workflowDeleted,
      id: 'e1',
      payload: const WorkflowDeletedPayload(
        operationId: 'op-1',
        workflowId: 'wf-1',
        deletedRuns: 2,
      ).toJson(),
    );

    final finished = decodeWorkflowDeletionEvent(envelope)!;

    expect(finished.operationId, 'op-1');
    expect(finished.failure, isNull);
  });

  test('decodes workflow.delete.failed as BackendFailure(message, code)', () {
    final envelope = WsEnvelope(
      type: WsMessageType.workflowDeleteFailed,
      id: 'e2',
      payload: const WorkflowDeleteFailedPayload(
        operationId: 'op-1',
        workflowId: 'wf-1',
        code: ApiErrorCode.workflowHasActiveRuns,
        message: 'Stop them first.',
      ).toJson(),
    );

    final finished = decodeWorkflowDeletionEvent(envelope)!;

    expect(finished.operationId, 'op-1');
    final failure = finished.failure! as BackendFailure;
    expect(failure.message, 'Stop them first.');
    expect(failure.code, ApiErrorCode.workflowHasActiveRuns);
  });

  test('returns null for workflow.delete.progress', () {
    final envelope = WsEnvelope(
      type: WsMessageType.workflowDeleteProgress,
      id: 'e3',
      payload: WorkflowDeletionStatus(
        operationId: 'op-1',
        workflowId: 'wf-1',
        phase: WorkflowDeletionPhase.stoppingRuns,
        startedAt: DateTime.utc(2026, 11, 23),
      ).toJson(),
    );

    expect(decodeWorkflowDeletionEvent(envelope), isNull);
  });

  test('returns null for other message types', () {
    const envelope = WsEnvelope(type: WsMessageType.workflowsChanged, id: 'e4');

    expect(decodeWorkflowDeletionEvent(envelope), isNull);
  });

  test('returns null for a malformed payload', () {
    const envelope = WsEnvelope(
      type: WsMessageType.workflowDeleted,
      id: 'e5',
      payload: {'unexpected': true},
    );

    expect(decodeWorkflowDeletionEvent(envelope), isNull);
  });
}
