import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

WorkflowDeletionOperation op(
  String id,
  String workflowId, {
  String? workspaceId,
}) => WorkflowDeletionOperation(
  id: id,
  workflowId: workflowId,
  scope: DefinitionScope.ofWorkspaceId(workspaceId),
  phase: WorkflowDeletionPhase.deletingRuns,
  startedAt: DateTime.utc(2026),
);

WorkflowDeletionOperation finished(WorkflowDeletionOperation operation) =>
    operation.copyWith(
      phase: WorkflowDeletionPhase.done,
      outcome: WorkflowDeletionOutcome.deleted,
      finishedAt: DateTime.utc(2026, 1, 2),
    );

void main() {
  test('start registers a running operation found by byId and runningFor', () {
    final registry = WorkflowDeletionRegistry();
    final operation = op('op-1', 'wf-1');
    registry.start(operation);
    expect(registry.byId('op-1'), operation);
    expect(registry.runningFor('wf-1'), operation);
  });

  test('runningFor separates scopes', () {
    final registry = WorkflowDeletionRegistry()
      ..start(op('global', 'deploy'))
      ..start(op('ws', 'deploy', workspaceId: 'ws-1'));

    expect(registry.runningFor('deploy')!.id, 'global');
    expect(
      registry.runningFor('deploy', scope: const WorkspaceScope('ws-1'))!.id,
      'ws',
    );
    expect(
      registry.runningFor('deploy', scope: const WorkspaceScope('ws-2')),
      isNull,
    );
  });

  test('start throws StateError when the workflow already has a running '
      'operation', () {
    final registry = WorkflowDeletionRegistry()..start(op('op-1', 'wf-1'));

    expect(
      () => registry.start(op('op-2', 'wf-1')),
      throwsA(isA<StateError>()),
    );
  });

  test('update replaces the snapshot', () {
    final registry = WorkflowDeletionRegistry()..start(op('op-1', 'wf-1'));

    final updated = registry.update(
      'op-1',
      (current) => current.copyWith(
        phase: WorkflowDeletionPhase.stoppingRuns,
        runsToStop: 3,
        runsStopped: 1,
      ),
    );

    expect(updated.phase, WorkflowDeletionPhase.stoppingRuns);
    expect(registry.byId('op-1')!.runsToStop, 3);
    expect(registry.byId('op-1')!.runsStopped, 1);
    expect(registry.runningFor('wf-1'), isNotNull);
  });

  test('finishing (outcome set) clears runningFor and completes '
      'whenFinished', () async {
    final registry = WorkflowDeletionRegistry()..start(op('op-1', 'wf-1'));
    final pending = registry.whenFinished('op-1')!;

    registry.update('op-1', finished);

    expect(registry.runningFor('wf-1'), isNull);
    expect((await pending).outcome, WorkflowDeletionOutcome.deleted);
  });

  test('whenFinished of a finished operation completes immediately; of an '
      'unknown id returns null', () async {
    final registry = WorkflowDeletionRegistry()
      ..start(op('op-1', 'wf-1'))
      ..update('op-1', finished);

    expect(
      (await registry.whenFinished('op-1')!).outcome,
      WorkflowDeletionOutcome.deleted,
    );
    expect(registry.whenFinished('missing'), isNull);
  });

  test('keeps the last 50 finished operations', () {
    final registry = WorkflowDeletionRegistry();
    for (var i = 1; i <= 51; i++) {
      registry
        ..start(op('op-$i', 'wf-$i'))
        ..update('op-$i', finished);
    }

    expect(registry.byId('op-1'), isNull);
    expect(registry.byId('op-2'), isNotNull);
    expect(registry.byId('op-51'), isNotNull);
  });

  test('never evicts running operations', () {
    final registry = WorkflowDeletionRegistry();
    for (var i = 1; i <= 51; i++) {
      registry.start(op('op-$i', 'wf-$i'));
    }

    for (var i = 1; i <= 51; i++) {
      expect(registry.byId('op-$i'), isNotNull);
    }
  });
}
