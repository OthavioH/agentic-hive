import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/runs_list_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../workspace/fake_workspace_repository.dart';

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  String? savedId;

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async {
    savedId = workspaceId;
  }
}

List<Override> _workspaceOverrides() => [
  workspaceRepositoryProvider.overrideWithValue(
    FakeWorkspaceRepository(workspaces: <Workspace>[makeWorkspace()]),
  ),
  workspaceSelectionStoreProvider.overrideWithValue(_FakeSelectionStore()),
];

final class _FakeRunRepository implements RunRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);
  final List<RunSummary> items = <RunSummary>[];
  Result<RunsListResponse>? listOverride;
  Result<void> deleteOverride = const Success<void>(null);
  RunStatus? lastStatusFilter;
  String? lastWorkflowFilter;
  int? lastLimit;
  int? lastOffset;
  final List<String> deletedIds = <String>[];

  void seedDefaults() {
    items
      ..clear()
      ..addAll(<RunSummary>[
        RunSummary(
          id: 'run-1',
          workspaceId: 'ws-1',
          workflowId: 'wf-1',
          workflowName: 'PR Review',
          status: RunStatus.succeeded,
          startedAt: now,
          finishedAt: DateTime.utc(2026, 11, 21, 4, 30, 25),
          checkpointCount: 2,
        ),
        RunSummary(
          id: 'run-2',
          workspaceId: 'ws-1',
          workflowId: 'wf-2',
          workflowName: 'Deploy Check',
          status: RunStatus.running,
          startedAt: now,
          checkpointCount: 1,
        ),
      ]);
  }

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async {
    lastStatusFilter = status;
    lastWorkflowFilter = workflowId;
    lastLimit = limit;
    lastOffset = offset;
    if (listOverride != null) return listOverride!;
    final filtered = items.where((run) {
      if (status != null && run.status != status) return false;
      if (workflowId != null && run.workflowId != workflowId) return false;
      return true;
    }).toList();
    final start = offset ?? 0;
    final page = limit == null
        ? filtered.skip(start).toList()
        : filtered.skip(start).take(limit).toList();
    return Success(RunsListResponse(items: page, total: filtered.length));
  }

  @override
  Future<Result<Run>> getRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      const Success(<Checkpoint>[]);

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> cancelRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> resumeRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteRun(String id) async {
    deletedIds.add(id);
    if (deleteOverride.isFailure) return deleteOverride;
    items.removeWhere((run) => run.id == id);
    return const Success(null);
  }
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async => Success(<WorkflowSummary>[
    WorkflowSummary(
      id: 'wf-1',
      name: 'PR Review',
      nodeCount: 2,
      edgeCount: 1,
      hasValidationErrors: false,
      updatedAt: now,
    ),
    WorkflowSummary(
      id: 'wf-2',
      name: 'Deploy Check',
      nodeCount: 1,
      edgeCount: 0,
      hasValidationErrors: false,
      updatedAt: now,
    ),
  ]);

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) => Stream.value(const WorkflowDeletionSucceeded());

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

void main() {
  group('RunsListController', () {
    test('loads runs and workflows on build', () async {
      final runRepo = _FakeRunRepository()..seedDefaults();
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          runRepositoryProvider.overrideWithValue(runRepo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
          ..._workspaceOverrides(),
        ],
      );

      final state = await container.read(runsListControllerProvider.future);
      expect(state.runs, hasLength(2));
      expect(state.workflows, hasLength(2));
      expect(state.statusFilter, isNull);
      expect(state.workflowFilter, isNull);
    });

    test('filters by status and workflow, and clears filters', () async {
      final runRepo = _FakeRunRepository()..seedDefaults();
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          runRepositoryProvider.overrideWithValue(runRepo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
          ..._workspaceOverrides(),
        ],
      );
      await container.read(runsListControllerProvider.future);

      final notifier = container.read(runsListControllerProvider.notifier);
      await notifier.setStatusFilter(RunStatus.succeeded);
      var current = container.read(runsListControllerProvider).requireValue;
      expect(current.statusFilter, RunStatus.succeeded);
      expect(current.runs.map((r) => r.id), <String>['run-1']);

      await notifier.setWorkflowFilter('wf-2');
      current = container.read(runsListControllerProvider).requireValue;
      expect(current.workflowFilter, 'wf-2');
      expect(current.runs, isEmpty);

      await notifier.clearFilters();
      current = container.read(runsListControllerProvider).requireValue;
      expect(current.hasActiveFilters, isFalse);
      expect(current.runs, hasLength(2));
    });

    test(
      'deleteRun removes item on success and records actionFailure on error',
      () async {
        final runRepo = _FakeRunRepository()..seedDefaults();
        final container = ProviderContainer.test(
          overrides: [
            runRepositoryProvider.overrideWithValue(runRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            ..._workspaceOverrides(),
          ],
        );
        await container.read(runsListControllerProvider.future);

        final notifier = container.read(runsListControllerProvider.notifier);
        final ok = await notifier.deleteRun('run-1');
        expect(ok.isSuccess, isTrue);
        expect(
          container.read(runsListControllerProvider).requireValue.runs,
          hasLength(1),
        );

        runRepo.deleteOverride = const FailureResult(
          BackendFailure('Cannot delete active run', statusCode: 409),
        );
        final err = await notifier.deleteRun('run-2');
        expect(err.isFailure, isTrue);
        expect(
          container.read(runsListControllerProvider).requireValue.actionFailure,
          isA<BackendFailure>(),
        );
      },
    );

    test('surfaces AsyncError when listRuns fails', () async {
      final runRepo = _FakeRunRepository()
        ..listOverride = const FailureResult(NetworkFailure('offline'));
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          runRepositoryProvider.overrideWithValue(runRepo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
          ..._workspaceOverrides(),
        ],
      );

      final sub = container.listen(runsListControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(runsListControllerProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(sub.read().hasError, isTrue);
    });

    test(
      'loadMore appends next page using offset and updates hasMore',
      () async {
        final runRepo = _FakeRunRepository();
        for (var i = 0; i < 60; i++) {
          runRepo.items.add(
            RunSummary(
              id: 'run-$i',
              workspaceId: 'ws-1',
              workflowId: 'wf-1',
              workflowName: 'PR Review',
              status: RunStatus.succeeded,
              startedAt: runRepo.now,
              finishedAt: DateTime.utc(2026, 11, 21, 4, 30, 5),
              checkpointCount: 1,
            ),
          );
        }

        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            runRepositoryProvider.overrideWithValue(runRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            ..._workspaceOverrides(),
          ],
        );

        final initial = await container.read(runsListControllerProvider.future);
        expect(initial.runs, hasLength(50));
        expect(initial.total, 60);
        expect(initial.hasMore, isTrue);
        expect(runRepo.lastLimit, 50);
        expect(runRepo.lastOffset, 0);

        await container.read(runsListControllerProvider.notifier).loadMore();
        final afterMore = container
            .read(runsListControllerProvider)
            .requireValue;
        expect(afterMore.runs, hasLength(60));
        expect(afterMore.hasMore, isFalse);
        expect(runRepo.lastOffset, 50);
      },
    );

    test(
      'ignores out-of-order filter response when a newer filter wins',
      () async {
        final slowRepo = _OutOfOrderFakeRunRepository();
        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            runRepositoryProvider.overrideWithValue(slowRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            ..._workspaceOverrides(),
          ],
        );

        await container.read(runsListControllerProvider.future);
        final notifier = container.read(runsListControllerProvider.notifier);

        final first = notifier.setStatusFilter(RunStatus.failed);
        final second = notifier.setStatusFilter(RunStatus.succeeded);

        // Complete the newer request first, then the stale one.
        slowRepo.completers[RunStatus.succeeded]!.complete(
          Success(
            RunsListResponse(
              items: [
                RunSummary(
                  id: 'new-run',
                  workspaceId: 'ws-1',
                  workflowName: 'PR Review',
                  status: RunStatus.succeeded,
                  startedAt: slowRepo.now,
                  checkpointCount: 0,
                ),
              ],
              total: 1,
            ),
          ),
        );
        await second;

        slowRepo.completers[RunStatus.failed]!.complete(
          Success(
            RunsListResponse(
              items: [
                RunSummary(
                  id: 'stale-run',
                  workspaceId: 'ws-1',
                  workflowName: 'PR Review',
                  status: RunStatus.failed,
                  startedAt: slowRepo.now,
                  checkpointCount: 0,
                ),
              ],
              total: 1,
            ),
          ),
        );
        await first;

        final current = container.read(runsListControllerProvider).requireValue;
        expect(current.statusFilter, RunStatus.succeeded);
        expect(current.runs.single.id, 'new-run');
      },
    );

    test('filters runs to currentWorkspaceId and pages client-side across '
        'other workspaces', () async {
      final repo = _FakeRunRepository();
      // 55 runs for ws-2 (newest) followed by 3 runs for ws-1.
      for (var i = 0; i < 55; i++) {
        repo.items.add(
          RunSummary(
            id: 'other-$i',
            workspaceId: 'ws-2',
            workflowName: 'Other',
            status: RunStatus.succeeded,
            startedAt: repo.now,
            checkpointCount: 0,
          ),
        );
      }
      for (var i = 0; i < 3; i++) {
        repo.items.add(
          RunSummary(
            id: 'mine-$i',
            workspaceId: 'ws-1',
            workflowName: 'Mine',
            status: RunStatus.succeeded,
            startedAt: repo.now,
            checkpointCount: 0,
          ),
        );
      }
      final wsRepo = FakeWorkspaceRepository(
        workspaces: <Workspace>[makeWorkspace()],
      );
      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
          workspaceRepositoryProvider.overrideWithValue(wsRepo),
          workspaceSelectionStoreProvider.overrideWithValue(
            _FakeSelectionStore(),
          ),
        ],
      );

      final state = await container.read(runsListControllerProvider.future);
      expect(state.isGlobalSelected, isFalse);
      expect(state.runs.map((r) => r.id), <String>[
        'mine-0',
        'mine-1',
        'mine-2',
      ]);
    });

    test(
      'shows empty runs and isGlobalSelected=true when Global is selected',
      () async {
        final repo = _FakeRunRepository()..seedDefaults();
        final wsRepo = FakeWorkspaceRepository(
          workspaces: <Workspace>[makeWorkspace()],
        );
        final container = ProviderContainer.test(
          overrides: [
            runRepositoryProvider.overrideWithValue(repo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(wsRepo),
            workspaceSelectionStoreProvider.overrideWithValue(
              _FakeSelectionStore(),
            ),
          ],
        );
        await container.read(workspaceRegistryControllerProvider.future);
        container
            .read(workspaceRegistryControllerProvider.notifier)
            .selectGlobal();

        final state = await container.read(runsListControllerProvider.future);
        expect(state.isGlobalSelected, isTrue);
        expect(state.runs, isEmpty);
      },
    );
  });
}

final class _OutOfOrderFakeRunRepository extends _FakeRunRepository {
  final Map<RunStatus?, Completer<Result<RunsListResponse>>> completers = {};

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) {
    if (status == null && workflowId == null) {
      return super.listRuns(
        status: status,
        workflowId: workflowId,
        limit: limit,
        offset: offset,
      );
    }
    final completer = Completer<Result<RunsListResponse>>();
    completers[status] = completer;
    return completer.future;
  }
}
