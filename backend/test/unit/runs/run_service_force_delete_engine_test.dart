import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../engine/support/engine_harness.dart';
import '../engine/support/fake_ports.dart';

void main() {
  test(
    'forced delete waits for the confirmed kill, then deletes the run',
    () async {
      final h = EngineHarness();
      final service = RunService(
        runs: h.runs,
        checkpoints: h.checkpoints,
        events: h.events,
        engine: h.engine,
      );
      final wf = buildWorkflow(nodeIds: ['a'], edges: const []);
      const runId = 'run-1';
      await h.runs.create(
        Run(
          id: runId,
          workflowId: 'wf-1',
          workflowName: wf.name,
          workflowDefinition: wf,
          workspacePath: '/workspace',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );

      final hung = Completer<void>();
      h.killer.onKill = (_, _) {
        if (!hung.isCompleted) hung.complete();
      };
      h.script.on('a', [outcomeAfter(hung.future, NodeOutput.onSuccess)]);

      final started = h.engine.start(runId);
      await h.settle();

      final result = await service.deleteRunsOfWorkflow('wf-1', force: true);
      expect(result.valueOrNull?.deletedRuns, 1);
      expect(result.valueOrNull?.orphanedRuns, isEmpty);
      expect((await started).valueOrNull?.status, RunStatus.cancelled);
      expect(h.runs.runs, isEmpty);
    },
  );

  test('a kill that cannot be confirmed orphans the run; retry cancel then delete works', () async {
    final h = EngineHarness();
    final service = RunService(
      runs: h.runs,
      checkpoints: h.checkpoints,
      events: h.events,
      engine: h.engine,
    );
    final wf = buildWorkflow(nodeIds: ['a'], edges: const []);
    const runId = 'run-1';
    await h.runs.create(
      Run(
        id: runId,
        workflowId: 'wf-1',
        workflowName: wf.name,
        workflowDefinition: wf,
        workspacePath: '/workspace',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
      ),
    );

    final hung = Completer<void>();
    h.killer.failure = const NodeExecutionFailure('still alive');
    h.killer.onKill = (_, _) {
      if (h.killer.failure == null && !hung.isCompleted) {
        hung.complete();
      }
    };
    h.script.on('a', [outcomeAfter(hung.future, NodeOutput.onSuccess)]);

    final started = h.engine.start(runId);
    await h.settle();

    final result = await service.deleteRunsOfWorkflow('wf-1', force: true);
    expect(result.valueOrNull?.deletedRuns, 0);
    expect(result.valueOrNull?.orphanedRuns, [runId]);
    await started;

    final orphan = (await h.runs.getById(runId)).valueOrNull!;
    expect(orphan.workflowId, isNull);
    expect(orphan.status, RunStatus.cancellationUncertain);
    expect(orphan.workflowName, wf.name);

    h.killer.failure = null;
    final retried = await service.cancelRun(runId);
    expect(retried.valueOrNull?.status, RunStatus.cancelled);

    final removed = await service.deleteRun(runId);
    expect(removed.isSuccess, isTrue);
    expect(h.runs.runs, isEmpty);
  });
}
