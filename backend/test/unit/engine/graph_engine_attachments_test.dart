import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';
import 'support/fake_ports.dart';

void main() {
  group('GraphEngine run attachments lifecycle', () {
    test('deletes attachments folder when run succeeds', () async {
      final h = EngineHarness();
      final wf = buildWorkflow(nodeIds: ['a'], edges: []);
      await h.createRun(wf);
      h.attachments.folders.add(runId);
      h.script.on('a', [outcome('onSuccess')]);

      final result = await h.engine.start(runId);

      expect(result, isA<Success<Run>>());
      expect(result.valueOrNull!.status, RunStatus.succeeded);
      expect(h.attachments.folders, isNot(contains(runId)));
    });

    test('deletes attachments folder when run fails', () async {
      final h = EngineHarness(circuitBreakerThreshold: 1);
      final wf = buildWorkflow(nodeIds: ['a'], edges: []);
      await h.createRun(wf);
      h.attachments.folders.add(runId);
      h.script.on('a', [infraFailure('boom')]);

      final result = await h.engine.start(runId);

      expect(result, isA<Success<Run>>());
      expect(result.valueOrNull!.status, RunStatus.failed);
      expect(h.attachments.folders, isNot(contains(runId)));
    });

    test('keeps folder while paused and deletes it when cancelled', () async {
      final h = EngineHarness();
      final wf = buildWorkflow(
        nodeIds: ['a', 'approve', 'b'],
        edges: [
          edge('a', 'onSuccess', 'approve'),
          edge('approve', 'approved', 'b'),
        ],
        approvals: {'approve'},
      );
      await h.createRun(wf);
      h.attachments.folders.add(runId);
      h.script.on('a', [outcome('onSuccess')]);

      final paused = await h.engine.start(runId);
      expect(paused, isA<Success<Run>>());
      expect(paused.valueOrNull!.status, RunStatus.paused);
      expect(h.attachments.folders, contains(runId));

      final cancelled = await h.engine.cancel(runId);
      expect(cancelled, isA<Success<void>>());
      final run = (await h.runs.getById(runId)).valueOrNull!;
      expect(run.status, RunStatus.cancelled);
      expect(h.attachments.folders, isNot(contains(runId)));
    });

    test(
      'keeps folder when interrupted and on resume until completion',
      () async {
        final h = EngineHarness();
        final wf = buildWorkflow(
          nodeIds: ['a', 'approve', 'b'],
          edges: [
            edge('a', 'onSuccess', 'approve'),
            edge('approve', 'approved', 'b'),
          ],
          approvals: {'approve'},
        );
        await h.createRun(wf);
        await h.runs.updateStatus(runId, status: RunStatus.interrupted);
        h.attachments.folders.add(runId);
        h.script
          ..on('a', [outcome('onSuccess')])
          ..on('b', [outcome('onSuccess')]);

        final resumedToPause = await h.engine.resume(runId);
        expect(resumedToPause, isA<Success<Run>>());
        expect(resumedToPause.valueOrNull!.status, RunStatus.paused);
        expect(h.attachments.folders, contains(runId));

        final resumedToEnd = await h.engine.resume(
          runId,
          input: const ApprovalDecisionInput(
            nodeId: 'approve',
            decision: HumanApprovalDecision.approved,
          ),
        );
        expect(resumedToEnd, isA<Success<Run>>());
        expect(resumedToEnd.valueOrNull!.status, RunStatus.succeeded);
        expect(h.attachments.folders, isNot(contains(runId)));
      },
    );

    test('keeps folder when recovery ends in cancellationUncertain', () async {
      final h = EngineHarness();
      final wf = buildWorkflow(nodeIds: ['a'], edges: []);
      await h.createRun(wf);
      await h.runs.updateStatus(runId, status: RunStatus.cancelling);
      h.attachments.folders.add(runId);

      final recovered = await h.recovery.recoverOrphanedRuns();
      expect(recovered, isA<Success<int>>());
      final run = (await h.runs.getById(runId)).valueOrNull!;
      expect(run.status, RunStatus.cancellationUncertain);
      expect(h.attachments.folders, contains(runId));
    });

    test('logs and still succeeds when attachment deletion fails', () async {
      final h = EngineHarness();
      h.attachments.failDeletes = true;
      final wf = buildWorkflow(nodeIds: ['a'], edges: []);
      await h.createRun(wf);
      h.attachments.folders.add(runId);
      h.script.on('a', [outcome('onSuccess')]);

      final result = await h.engine.start(runId);

      expect(result, isA<Success<Run>>());
      expect(result.valueOrNull!.status, RunStatus.succeeded);
      expect(h.attachments.deleteCalls, contains(runId));
      expect(
        h.events.events.any((e) => e.type == RunEventType.runSucceeded),
        isTrue,
      );
    });
  });
}
