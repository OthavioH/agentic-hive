import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes workflow.deleted as a successful finish with counts', () {
    final envelope = WsEnvelope(
      type: WsMessageType.workflowDeleted,
      id: 'e1',
      payload: const WorkflowDeletedPayload(
        operationId: 'op-1',
        workflowId: 'wf-1',
        deletedRuns: 2,
        workspaceId: 'ws-1',
        orphanedRuns: ['run-9'],
      ).toJson(),
    );

    final finished = decodeWorkflowDeletionEvent(envelope)!;

    expect(finished.operationId, 'op-1');
    expect(finished.workflowId, 'wf-1');
    expect(finished.workspaceId, 'ws-1');
    expect(finished.failure, isNull);
    expect(finished.deletedRuns, 2);
    expect(finished.orphanedRuns, ['run-9']);
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
        deletedRuns: 1,
        orphanedRuns: ['run-3'],
      ).toJson(),
    );

    final finished = decodeWorkflowDeletionEvent(envelope)!;

    expect(finished.operationId, 'op-1');
    final failure = finished.failure! as BackendFailure;
    expect(failure.message, 'Stop them first.');
    expect(failure.code, ApiErrorCode.workflowHasActiveRuns);
    expect(finished.deletedRuns, 1);
    expect(finished.orphanedRuns, ['run-3']);
  });

  test('decodeWorkflowDeletionProgress decodes workflow.delete.progress', () {
    final envelope = WsEnvelope(
      type: WsMessageType.workflowDeleteProgress,
      id: 'e3',
      payload: WorkflowDeletionStatus(
        operationId: 'op-1',
        workflowId: 'wf-1',
        phase: WorkflowDeletionPhase.stoppingRuns,
        startedAt: DateTime.utc(2026, 11, 23),
        runsToStop: 3,
        runsStopped: 2,
      ).toJson(),
    );

    final status = decodeWorkflowDeletionProgress(envelope)!;

    expect(status.phase, WorkflowDeletionPhase.stoppingRuns);
    expect(status.runsToStop, 3);
    expect(status.runsStopped, 2);
    expect(decodeWorkflowDeletionEvent(envelope), isNull);
  });

  test('decodeWorkflowDeletionProgress returns null for other types and '
      'malformed payloads', () {
    const other = WsEnvelope(type: WsMessageType.workflowsChanged, id: 'e4');
    const malformed = WsEnvelope(
      type: WsMessageType.workflowDeleteProgress,
      id: 'e5',
      payload: {'unexpected': true},
    );

    expect(decodeWorkflowDeletionProgress(other), isNull);
    expect(decodeWorkflowDeletionProgress(malformed), isNull);
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
