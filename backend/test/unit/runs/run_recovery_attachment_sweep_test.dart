import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_recovery_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../engine/support/engine_harness.dart';
import '../engine/support/fake_ports.dart';
import '../engine/support/in_memory_repositories.dart';

void main() {
  group('RunRecoveryService attachment sweep', () {
    late InMemoryRunRepository runs;
    late InMemoryCheckpointRepository checkpoints;
    late FakeRunAttachmentStore attachments;
    late RunRecoveryService recovery;
    late Workflow wf;

    setUp(() {
      runs = InMemoryRunRepository();
      checkpoints = InMemoryCheckpointRepository();
      attachments = FakeRunAttachmentStore();
      recovery = RunRecoveryService(
        runs: runs,
        checkpoints: checkpoints,
        attachments: attachments,
      );
      wf = buildWorkflow(nodeIds: ['a'], edges: []);
    });

    Future<void> addRun(String id, RunStatus status) async {
      await runs.create(
        Run(
          id: id,
          workflowId: wf.id,
          workflowName: wf.name,
          workflowDefinition: wf,
          workspaceId: 'ws-1',
          workspaceRoot: '/ws',
          status: status,
          startedAt: DateTime.utc(2026),
        ),
      );
      attachments.folders.add(id);
    }

    test(
      'deletes ended and missing run folders after recovery, keeps others',
      () async {
        await addRun('run-succeeded', RunStatus.succeeded);
        await addRun('run-failed', RunStatus.failed);
        await addRun('run-cancelled', RunStatus.cancelled);
        await addRun('run-running', RunStatus.running);
        await addRun('run-cancelling', RunStatus.cancelling);
        await addRun('run-paused', RunStatus.paused);
        await addRun('run-interrupted', RunStatus.interrupted);
        await addRun('run-uncertain', RunStatus.cancellationUncertain);
        attachments.folders.add('run-missing');

        final result = await recovery.recoverOrphanedRuns();

        expect(result, isA<Success<int>>());
        expect(result.valueOrNull, 2);
        expect(attachments.folders, {
          'run-running',
          'run-cancelling',
          'run-paused',
          'run-interrupted',
          'run-uncertain',
        });
      },
    );

    test('still succeeds when deleteRun fails', () async {
      await addRun('run-succeeded', RunStatus.succeeded);
      attachments.failDeletes = true;

      final result = await recovery.recoverOrphanedRuns();

      expect(result, isA<Success<int>>());
      expect(attachments.deleteCalls, contains('run-succeeded'));
    });

    test('still succeeds when listRunIds fails', () async {
      attachments.failListRunIds = true;

      final result = await recovery.recoverOrphanedRuns();

      expect(result, isA<Success<int>>());
    });
  });
}
