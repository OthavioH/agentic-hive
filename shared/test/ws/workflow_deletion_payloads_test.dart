import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) => jsonDecode(jsonEncode(json)) as JsonMap;

void main() {
  test('WorkflowDeletedPayload round-trips', () {
    const payload = WorkflowDeletedPayload(
      operationId: 'op-1',
      workflowId: 'wf-1',
      deletedRuns: 2,
      workspaceId: 'ws-1',
      orphanedRuns: ['r9'],
    );
    expect(
      WorkflowDeletedPayload.fromJson(_overTheWire(payload.toJson())),
      payload,
    );
  });

  test('WorkflowDeletedPayload defaults orphanedRuns to []', () {
    final decoded = WorkflowDeletedPayload.fromJson({
      'operationId': 'op-1',
      'workflowId': 'wf-1',
      'deletedRuns': 0,
    });
    expect(decoded.orphanedRuns, isEmpty);
  });

  test('WorkflowDeleteFailedPayload round-trips', () {
    const payload = WorkflowDeleteFailedPayload(
      operationId: 'op-1',
      workflowId: 'wf-1',
      code: 'workflow_has_active_runs',
      message: 'Stop them first.',
      deletedRuns: 1,
      orphanedRuns: ['r9'],
    );
    expect(
      WorkflowDeleteFailedPayload.fromJson(_overTheWire(payload.toJson())),
      payload,
    );
  });

  test('WorkflowDeleteFailedPayload requires code and message', () {
    expect(
      () => WorkflowDeleteFailedPayload.fromJson({
        'operationId': 'op-1',
        'workflowId': 'wf-1',
        'message': 'x',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => WorkflowDeleteFailedPayload.fromJson({
        'operationId': 'op-1',
        'workflowId': 'wf-1',
        'code': 'x',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('message types are workflow.delete.progress, workflow.deleted, '
      'workflow.delete.failed', () {
    expect(WsMessageType.workflowDeleteProgress, 'workflow.delete.progress');
    expect(WsMessageType.workflowDeleted, 'workflow.deleted');
    expect(WsMessageType.workflowDeleteFailed, 'workflow.delete.failed');
  });
}
