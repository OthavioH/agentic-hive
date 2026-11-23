import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_delete_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflows_list_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_workflow_repository.dart';

final _updatedAt = DateTime.utc(2026, 11, 20, 12);

WorkflowSummary _workflow({
  String id = 'wf-1',
  String name = 'Release Flow',
  String? workspaceId = 'ws-1',
  String revision = 'r1',
}) => WorkflowSummary(
  id: id,
  name: name,
  workspaceId: workspaceId,
  nodeCount: 1,
  edgeCount: 0,
  hasValidationErrors: false,
  updatedAt: _updatedAt,
  revision: revision,
);

ProviderContainer _container(ScriptedWorkflowRepository repo) {
  final container = ProviderContainer.test(
    overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
  );
  return container;
}

void main() {
  late ScriptedWorkflowRepository repo;
  late ProviderContainer container;
  late WorkflowDeleteController controller;

  WorkflowDeleteController notifier() =>
      container.read(workflowDeleteControllerProvider.notifier);

  setUp(() {
    repo = ScriptedWorkflowRepository()
      ..items.addAll(<WorkflowSummary>[
        _workflow(),
        _workflow(id: 'wf-2', name: 'Lint Check', workspaceId: null),
      ]);
    container = _container(repo);
    controller = notifier();
  });

  tearDown(() async {
    for (final live in repo.live) {
      await live.close();
    }
  });

  Future<WorkflowDeleteOutcome> start(
    WorkflowSummary workflow, {
    bool force = false,
    String? revision,
  }) => controller.delete(
    container.read(deleteWorkflowProvider),
    workflow,
    force: force,
    revision: revision,
  );

  WorkflowDeleteState state() =>
      container.read(workflowDeleteControllerProvider);

  final wf1 = _workflow();
  final key1 = workflowKeyOf(wf1);
  final wf2 = _workflow(id: 'wf-2', name: 'Lint Check', workspaceId: null);
  final key2 = workflowKeyOf(wf2);

  test('delete marks the row deleting at once and sends workspaceId and '
      'revision', () async {
    final pending = start(wf1);

    expect(state().progress.containsKey(key1), isTrue);
    expect(state().progress[key1]!.phase, isNull);
    expect(repo.deleteCalls.single, (
      id: 'wf-1',
      workspaceId: 'ws-1',
      revision: 'r1',
      force: false,
    ));

    repo.live.single.add(const WorkflowDeletionStarted(operationId: 'op-1'));
    expect(await pending, isA<WorkflowDeleteHandled>());
  });

  test('delete completes Handled on Started', () async {
    repo.scripts.add(<WorkflowDeletionUpdate>[
      const WorkflowDeletionStarted(operationId: 'op-1'),
    ]);

    expect(await start(wf1), isA<WorkflowDeleteHandled>());
    expect(state().progress.containsKey(key1), isTrue);
  });

  test('Progressed updates the row progress', () async {
    final pending = start(wf1);
    repo.live.single
      ..add(const WorkflowDeletionStarted(operationId: 'op-1'))
      ..add(
        const WorkflowDeletionProgressed(
          phase: WorkflowDeletionPhase.stoppingRuns,
          runsToStop: 3,
          runsStopped: 2,
        ),
      );
    await pending;
    await pumpEventQueue();

    final view = state().progress[key1]!;
    expect(view.phase, WorkflowDeletionPhase.stoppingRuns);
    expect(view.runsToStop, 3);
    expect(view.runsStopped, 2);
  });

  test('Succeeded without orphans removes the row and sets '
      'WorkflowDeletedNotice', () async {
    repo.scripts.add(<WorkflowDeletionUpdate>[
      const WorkflowDeletionStarted(operationId: 'op-1'),
      const WorkflowDeletionSucceeded(deletedRuns: 2),
    ]);

    await start(wf1);
    await pumpEventQueue();

    expect(state().notice, isA<WorkflowDeletedNotice>());
    expect(state().removed, contains(key1));
    expect(state().progress, isEmpty);
  });

  test(
    'Succeeded with orphans sets WorkflowDeletePartialNotice in order',
    () async {
      repo.scripts.add(<WorkflowDeletionUpdate>[
        const WorkflowDeletionStarted(operationId: 'op-1'),
        const WorkflowDeletionSucceeded(orphanedRuns: ['run-2', 'run-1']),
      ]);

      await start(wf1);
      await pumpEventQueue();

      final notice = state().notice! as WorkflowDeletePartialNotice;
      expect(notice.orphanedRunIds, ['run-2', 'run-1']);
    },
  );

  test('active runs refusal returns NeedsForce with the count and restores the '
      'row', () async {
    repo.scripts.add(<WorkflowDeletionUpdate>[activeRuns]);

    final outcome = await start(wf1);

    expect(outcome, isA<WorkflowDeleteNeedsForce>());
    expect((outcome as WorkflowDeleteNeedsForce).activeRunCount, 2);
    expect(state().progress, isEmpty);
    expect(state().notice, isNull);
  });

  test('a forced delete right after NeedsForce is sent', () async {
    repo.scripts.addAll(<List<WorkflowDeletionUpdate>>[
      <WorkflowDeletionUpdate>[activeRuns],
      <WorkflowDeletionUpdate>[
        const WorkflowDeletionStarted(operationId: 'op-1'),
        const WorkflowDeletionSucceeded(),
      ],
    ]);

    await start(wf1);
    await start(wf1, force: true);

    expect(repo.deleteCalls.map((c) => c.force), <bool>[false, true]);
  });

  test('active runs refusal without details becomes an error notice', () async {
    repo.scripts.add(<WorkflowDeletionUpdate>[
      const WorkflowDeletionRejected(
        BackendFailure(
          'Workflow has active runs.',
          code: ApiErrorCode.workflowHasActiveRuns,
          statusCode: 409,
        ),
      ),
    ]);

    await start(wf1);

    expect(state().notice, isA<WorkflowDeleteFailedNotice>());
  });

  test('revision conflict sets an error notice that reports a revision '
      'conflict', () async {
    repo.scripts.add(<WorkflowDeletionUpdate>[
      const WorkflowDeletionRejected(
        BackendFailure(
          'Revision changed.',
          code: ApiErrorCode.revisionConflict,
          statusCode: 409,
          details: {'currentRevision': 'r2'},
        ),
      ),
    ]);

    await start(wf1);

    final notice = state().notice! as WorkflowDeleteFailedNotice;
    expect(notice.isRevisionConflict, isTrue);
    expect(notice.force, isFalse);
  });

  test(
    'Failed after start keeps force and orphans in the error notice',
    () async {
      repo.scripts.add(<WorkflowDeletionUpdate>[
        const WorkflowDeletionStarted(operationId: 'op-1'),
        const WorkflowDeletionFailed(
          BackendFailure('Database is locked.', statusCode: 500),
          orphanedRuns: ['run-7'],
        ),
      ]);

      await start(wf1, force: true);
      await pumpEventQueue();

      final notice = state().notice! as WorkflowDeleteFailedNotice;
      expect(notice.force, isTrue);
      expect(notice.orphanedRunIds, ['run-7']);
      expect(notice.isRevisionConflict, isFalse);
      expect(state().progress, isEmpty);
    },
  );

  test('a second delete of a followed workflow sends nothing', () async {
    final pending = start(wf1);
    final second = await start(wf1);

    expect(second, isA<WorkflowDeleteHandled>());
    expect(repo.deleteCalls, hasLength(1));

    repo.live.single.add(const WorkflowDeletionStarted(operationId: 'op-1'));
    await pending;
  });

  test('starting a delete clears the previous notice', () async {
    repo.scripts.add(<WorkflowDeletionUpdate>[
      const WorkflowDeletionRejected(BackendFailure('boom')),
    ]);
    await start(wf1);
    expect(state().notice, isNotNull);

    final pending = start(wf2);

    expect(state().notice, isNull);
    repo.live.single.add(const WorkflowDeletionStarted(operationId: 'op-2'));
    await pending;
  });

  test('dismissNotice clears the notice and keeps progress', () async {
    final pendingFirst = start(wf1);
    final pendingSecond = start(wf2);
    repo.live.first.add(const WorkflowDeletionRejected(BackendFailure('boom')));
    await pendingFirst;
    await pumpEventQueue();
    expect(state().notice, isNotNull);
    expect(state().progress.containsKey(key2), isTrue);

    notifier().dismissNotice();

    expect(state().notice, isNull);
    expect(state().progress.containsKey(key2), isTrue);
    repo.live.last.add(const WorkflowDeletionStarted(operationId: 'op-2'));
    await pendingSecond;
  });

  test('the stream closing without an end update restores the row', () async {
    repo.scripts.add(<WorkflowDeletionUpdate>[
      const WorkflowDeletionStarted(operationId: 'op-1'),
    ]);

    await start(wf1);
    await pumpEventQueue();

    expect(state().progress, isEmpty);
    expect(state().notice, isNull);
  });

  test(
    'state survives without any list provider and keeps the notice',
    () async {
      final pending = start(wf1);
      repo.live.single
        ..add(const WorkflowDeletionStarted(operationId: 'op-1'))
        ..add(const WorkflowDeletionSucceeded());
      await pending;
      await pumpEventQueue();

      expect(state().notice, isA<WorkflowDeletedNotice>());
    },
  );

  test(
    'recreated workflow with the same id is removed from list on second '
    'deletion',
    () async {
    container.listen(workflowsListControllerProvider, (_, _) {});
    await container.read(workflowsListControllerProvider.future);
    expect(
      container
          .read(workflowsListControllerProvider)
          .value!
          .workflows
          .map((w) => w.id),
      contains(wf1.id),
    );

    final first = start(wf1);
    repo.live.last
      ..add(const WorkflowDeletionStarted(operationId: 'op-1'))
      ..add(const WorkflowDeletionSucceeded());
    await first;
    await pumpEventQueue();

    expect(
      container
          .read(workflowsListControllerProvider)
          .value!
          .workflows
          .map((w) => w.id),
      isNot(contains(wf1.id)),
    );

    // Recreate the workflow with the same id and refresh the list.
    repo.items.add(wf1);
    await container.read(workflowsListControllerProvider.notifier).refresh();
    expect(
      container
          .read(workflowsListControllerProvider)
          .value!
          .workflows
          .map((w) => w.id),
      contains(wf1.id),
    );

    // Second deletion (e.g. 404 or polling completion emitting Succeeded).
    final second = start(wf1);
    repo.live.last.add(const WorkflowDeletionSucceeded());
    await second;
    await pumpEventQueue();

    expect(
      container
          .read(workflowsListControllerProvider)
          .value!
          .workflows
          .map((w) => w.id),
      isNot(contains(wf1.id)),
    );
  });
}
