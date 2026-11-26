import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) => jsonDecode(jsonEncode(json)) as JsonMap;

void main() {
  final startedAt = DateTime.utc(2026, 11, 23, 10);
  final finishedAt = DateTime.utc(2026, 11, 23, 10, 0, 4);

  test('WorkflowDeletionAccepted round-trips {operationId, workflowId}', () {
    const accepted = WorkflowDeletionAccepted(
      operationId: 'op-1',
      workflowId: 'wf-1',
    );
    final json = _overTheWire(accepted.toJson());
    expect(json, {
      'operationId': 'op-1',
      'workflowId': 'wf-1',
      'references': <Object?>[],
    });
    expect(WorkflowDeletionAccepted.fromJson(json), accepted);
  });

  test(
    'WorkflowDeletionAccepted decodes a body without references as empty',
    () {
      final decoded = WorkflowDeletionAccepted.fromJson({
        'operationId': 'op-1',
        'workflowId': 'wf-1',
      });
      expect(decoded.references, isEmpty);
    },
  );

  test('WorkflowDeletionAccepted round-trips with references', () {
    const accepted = WorkflowDeletionAccepted(
      operationId: 'op-1',
      workflowId: 'wf-1',
      references: [
        WorkflowReference(
          workflowId: 'wf-parent',
          workflowName: 'Parent',
          nodeIds: ['n1'],
        ),
      ],
    );
    final json = _overTheWire(accepted.toJson());
    expect(WorkflowDeletionAccepted.fromJson(json), accepted);
  });

  test('WorkflowReference round-trips through json with nodeIds and scope', () {
    const ref = WorkflowReference(
      workflowId: 'wf-parent',
      workflowName: 'Parent',
      scope: WorkspaceScope('ws-1'),
      nodeIds: ['n1', 'n2'],
    );
    final json = _overTheWire(ref.toJson());
    expect(WorkflowReference.fromJson(json), ref);
  });

  test('WorkflowReferencesResponse defaults to an empty list', () {
    final decoded = WorkflowReferencesResponse.fromJson(<String, Object?>{});
    expect(decoded.references, isEmpty);
  });

  test('WorkflowDeletionAccepted.fromJson without operationId throws', () {
    expect(
      () => WorkflowDeletionAccepted.fromJson({'workflowId': 'wf-1'}),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'WorkflowDeletionPhase encodes as stopping_runs, deleting_runs, done',
    () {
      String phaseOf(WorkflowDeletionPhase phase) =>
          _overTheWire(
                WorkflowDeletionStatus(
                  operationId: 'op-1',
                  workflowId: 'wf-1',
                  phase: phase,
                  startedAt: startedAt,
                ).toJson(),
              )['phase']!
              as String;

      expect(phaseOf(WorkflowDeletionPhase.stoppingRuns), 'stopping_runs');
      expect(phaseOf(WorkflowDeletionPhase.deletingRuns), 'deleting_runs');
      expect(phaseOf(WorkflowDeletionPhase.done), 'done');
    },
  );

  test('WorkflowDeletionOutcome encodes as deleted and failed', () {
    String outcomeOf(WorkflowDeletionOutcome outcome) =>
        _overTheWire(
              WorkflowDeletionStatus(
                operationId: 'op-1',
                workflowId: 'wf-1',
                phase: WorkflowDeletionPhase.done,
                outcome: outcome,
                startedAt: startedAt,
              ).toJson(),
            )['outcome']!
            as String;

    expect(outcomeOf(WorkflowDeletionOutcome.deleted), 'deleted');
    expect(outcomeOf(WorkflowDeletionOutcome.failed), 'failed');
  });

  test('WorkflowDeletionStatus round-trips a finished failed operation', () {
    final status = WorkflowDeletionStatus(
      operationId: 'op-1',
      workflowId: 'wf-1',
      workspaceId: 'ws-1',
      phase: WorkflowDeletionPhase.done,
      startedAt: startedAt,
      runsToStop: 3,
      runsStopped: 2,
      runsDeleted: 1,
      orphanedRuns: const ['r9'],
      outcome: WorkflowDeletionOutcome.failed,
      errorCode: 'internal_error',
      errorMessage: 'Internal server error.',
      finishedAt: finishedAt,
    );
    expect(
      WorkflowDeletionStatus.fromJson(_overTheWire(status.toJson())),
      status,
    );
  });

  test(
    'WorkflowDeletionStatus omits null optional fields and defaults counters',
    () {
      final json = _overTheWire(
        WorkflowDeletionStatus(
          operationId: 'op-1',
          workflowId: 'wf-1',
          phase: WorkflowDeletionPhase.deletingRuns,
          startedAt: startedAt,
        ).toJson(),
      );
      expect(json.containsKey('workspaceId'), isFalse);
      expect(json.containsKey('outcome'), isFalse);
      expect(json.containsKey('errorCode'), isFalse);
      expect(json.containsKey('errorMessage'), isFalse);
      expect(json.containsKey('finishedAt'), isFalse);

      final decoded = WorkflowDeletionStatus.fromJson({
        'operationId': 'op-1',
        'workflowId': 'wf-1',
        'phase': 'deleting_runs',
        'startedAt': startedAt.toIso8601String(),
      });
      expect(decoded.runsToStop, 0);
      expect(decoded.runsStopped, 0);
      expect(decoded.runsDeleted, 0);
      expect(decoded.orphanedRuns, isEmpty);
      expect(decoded.outcome, isNull);
    },
  );
}
