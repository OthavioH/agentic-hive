import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../engine/support/engine_harness.dart';

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
  late EngineHarness h;
  late WorkflowDeletionRegistry registry;
  late RunService service;

  Future<void> seedRun(RunStatus status) => h.runs.create(
    Run(
      id: runId,
      workflowId: 'wf-1',
      workflowName: 'Test workflow',
      workflowDefinition: buildWorkflow(nodeIds: ['a'], edges: const []),
      workspacePath: '/workspace',
      workspaceId: 'ws-1',
      status: status,
      startedAt: DateTime.utc(2026),
    ),
  );

  setUp(() {
    h = EngineHarness();
    registry = WorkflowDeletionRegistry();
    service = RunService(
      runs: h.runs,
      checkpoints: h.checkpoints,
      events: h.events,
      engine: h.engine,
      deletions: registry,
    );
  });

  group('resumeRun (interrupted runs)', () {
    test('is refused with WorkflowDeletingFailure while the workflow is '
        'being deleted', () async {
      await seedRun(RunStatus.interrupted);
      registry.start(op('op-1', 'wf-1', workspaceId: 'ws-1'));

      final result = await service.resumeRun(runId);

      final failure = result.failureOrNull! as WorkflowDeletingFailure;
      expect(failure.operationId, 'op-1');
      expect(failure.message, 'Workflow "wf-1" is being deleted.');
      expect(
        (await h.runs.getById(runId)).valueOrNull?.status,
        RunStatus.interrupted,
      );
    });

    test('is refused while the global workflow with that id is being '
        'deleted', () async {
      await seedRun(RunStatus.interrupted);
      registry.start(op('op-2', 'wf-1'));

      final result = await service.resumeRun(runId);

      expect(
        (result.failureOrNull! as WorkflowDeletingFailure).operationId,
        'op-2',
      );
    });

    test('is allowed again after the deletion operation ends', () async {
      await seedRun(RunStatus.interrupted);
      registry
        ..start(op('op-1', 'wf-1', workspaceId: 'ws-1'))
        ..update(
          'op-1',
          (current) => current.copyWith(
            phase: WorkflowDeletionPhase.done,
            outcome: WorkflowDeletionOutcome.deleted,
          ),
        );

      final result = await service.resumeRun(runId);

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull?.id, runId);
      await service.waitForActiveExecutions();
    });
  });

  group('resumePausedRun (active paused runs)', () {
    test('is not guarded by a deletion of its workflow', () async {
      final workflow = buildWorkflow(
        nodeIds: ['work', 'gate', 'ship'],
        approvals: {'gate'},
        edges: [
          edge('work', NodeOutput.onSuccess, 'gate'),
          edge('gate', NodeOutput.approved, 'ship'),
        ],
      );
      await h.runs.create(
        Run(
          id: runId,
          workflowId: 'wf-1',
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspacePath: '/workspace',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );
      final paused = await h.engine.start(runId);
      expect(paused.valueOrNull?.status, RunStatus.paused);
      registry.start(op('op-1', 'wf-1', workspaceId: 'ws-1'));

      final result = await service.resumePausedRun(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull?.id, runId);
      await service.waitForActiveExecutions();
    });
  });
}
