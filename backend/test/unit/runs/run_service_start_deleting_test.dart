import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../engine/support/in_memory_repositories.dart';

WorkflowDeletionOperation op(
  String id,
  String workflowId, {
  String? workspaceId,
}) => WorkflowDeletionOperation(
  id: id,
  workflowId: workflowId,
  workspaceId: workspaceId,
  phase: WorkflowDeletionPhase.deletingRuns,
  startedAt: DateTime.utc(2026, 11, 23, 10),
);

void main() {
  late WorkflowDeletionRegistry registry;
  late RunService service;

  setUp(() {
    registry = WorkflowDeletionRegistry();
    service = RunService(
      runs: InMemoryRunRepository(),
      checkpoints: InMemoryCheckpointRepository(),
      events: InMemoryRunEventRepository(),
      deletions: registry,
    );
  });

  StartRunRequest request({
    String workflowId = 'wf-1',
    String workspaceId = 'ws-1',
  }) => StartRunRequest(workflowId: workflowId, workspaceId: workspaceId);

  test('startRun refuses with WorkflowDeletingFailure while the workflow is '
      'being deleted', () async {
    registry.start(op('op-1', 'wf-1', workspaceId: 'ws-1'));

    final result = await service.startRun(request());

    final failure = result.failureOrNull! as WorkflowDeletingFailure;
    expect(failure.operationId, 'op-1');
    expect(failure.message, 'Workflow "wf-1" is being deleted.');
  });

  test('startRun refuses while the global workflow with that id is being '
      'deleted', () async {
    registry.start(op('op-2', 'wf-1'));

    final result = await service.startRun(request());

    final failure = result.failureOrNull! as WorkflowDeletingFailure;
    expect(failure.operationId, 'op-2');
  });

  test('startRun passes the guard when nothing is being deleted', () async {
    final result = await service.startRun(request());

    final failure = result.failureOrNull!;
    expect(failure, isA<UnexpectedFailure>());
    expect(failure.message, 'Workspace registry is not configured.');
  });

  test('startRun passes the guard after the operation finished', () async {
    registry
      ..start(op('op-1', 'wf-1', workspaceId: 'ws-1'))
      ..update(
        'op-1',
        (current) => current.copyWith(
          phase: WorkflowDeletionPhase.done,
          outcome: WorkflowDeletionOutcome.deleted,
        ),
      );

    final result = await service.startRun(request());

    expect(result.failureOrNull, isNot(isA<WorkflowDeletingFailure>()));
  });
}
