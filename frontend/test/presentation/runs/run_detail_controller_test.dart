import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeRunRepository implements RunRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);
  Result<Run>? runOverride;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async {
    if (runOverride != null) return runOverride!;
    return Success(
      Run(
        id: id,
        workflowId: 'wf-1',
        workflowName: 'PR Review',
        workflowDefinition: Workflow(
          id: 'wf-1',
          name: 'PR Review',
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        workspacePath: '/tmp/repo',
        status: RunStatus.succeeded,
        startedAt: now,
        finishedAt: DateTime.utc(2026, 11, 21, 4, 30, 10),
      ),
    );
  }

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => Success(
    RunEventsResponse(
      items: <RunEvent>[
        RunEvent(
          id: 'evt-1',
          runId: id,
          sequence: 1,
          type: RunEventType.runStarted,
          createdAt: now,
          payload: const <String, Object?>{'step': 'init'},
        ),
      ],
      lastSequence: 1,
    ),
  );

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      Success(<Checkpoint>[
        Checkpoint(
          id: 'cp-1',
          runId: id,
          sequence: 1,
          completedNodeId: 'node-1',
          pendingNodeIds: const <String>['node-2'],
          attemptsByEdge: const <String, int>{'e-1': 1},
          circuitBreakerCount: 0,
          nodeOutputs: const <String, JsonMap>{
            'node-1': <String, Object?>{'status': 'ok'},
          },
          createdAt: now,
        ),
        Checkpoint(
          id: 'cp-2',
          runId: id,
          sequence: 2,
          completedNodeId: 'node-2',
          pendingNodeIds: const <String>[],
          attemptsByEdge: const <String, int>{},
          circuitBreakerCount: 0,
          nodeOutputs: const <String, JsonMap>{
            'node-2': <String, Object?>{'done': true},
          },
          createdAt: DateTime.utc(2026, 11, 21, 4, 30, 5),
        ),
      ]);

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

void main() {
  group('RunDetailController', () {
    test(
      'loads run, events, checkpoints and defaults to latest checkpoint',
      () async {
        final repo = _FakeRunRepository();
        final container = ProviderContainer.test(
          overrides: [runRepositoryProvider.overrideWithValue(repo)],
        );

        final state = await container.read(
          runDetailControllerProvider('run-1').future,
        );
        expect(state.run.id, 'run-1');
        expect(state.events, hasLength(1));
        expect(state.checkpoints, hasLength(2));
        expect(state.selectedCheckpointId, 'cp-2');
        expect(state.selectedCheckpoint?.sequence, 2);
        expect(state.expandedEventIds, isEmpty);
      },
    );

    test('selectCheckpoint and toggleEventExpanded update state', () async {
      final repo = _FakeRunRepository();
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [runRepositoryProvider.overrideWithValue(repo)],
      );
      await container.read(runDetailControllerProvider('run-1').future);

      final notifier = container.read(
        runDetailControllerProvider('run-1').notifier,
      )..selectCheckpoint('cp-1');
      var current = container
          .read(runDetailControllerProvider('run-1'))
          .requireValue;
      expect(current.selectedCheckpointId, 'cp-1');

      notifier.toggleEventExpanded('evt-1');
      current = container
          .read(runDetailControllerProvider('run-1'))
          .requireValue;
      expect(current.expandedEventIds, contains('evt-1'));

      notifier.toggleEventExpanded('evt-1');
      current = container
          .read(runDetailControllerProvider('run-1'))
          .requireValue;
      expect(current.expandedEventIds, isEmpty);
    });

    test('surfaces AsyncError when getRun fails', () async {
      final repo = _FakeRunRepository()
        ..runOverride = const FailureResult(NotFoundFailure('missing'));
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [runRepositoryProvider.overrideWithValue(repo)],
      );

      final sub = container.listen(
        runDetailControllerProvider('missing'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await expectLater(
        container.read(runDetailControllerProvider('missing').future),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(sub.read().hasError, isTrue);
    });
  });
}
