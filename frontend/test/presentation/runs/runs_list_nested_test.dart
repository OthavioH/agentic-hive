import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/runs_list_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
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
  final List<RunSummary> items = <RunSummary>[];
  int? backendTotalOverride;
  final List<String> deletedIds = <String>[];

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async {
    final filtered = workspaceId == null
        ? items
        : items.where((r) => r.workspaceId == workspaceId).toList();
    final start = offset ?? 0;
    final page = limit == null
        ? filtered.skip(start).toList()
        : filtered.skip(start).take(limit).toList();
    return Success(
      RunsListResponse(
        items: page,
        total: backendTotalOverride ?? filtered.length,
      ),
    );
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
    items.removeWhere((r) => r.id == id || r.parentRunId == id);
    return const Success(null);
  }
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success(<WorkflowSummary>[]);

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
  }) => const Stream<WorkflowDeletionUpdate>.empty();

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

final DateTime _baseTime = DateTime.utc(2026, 11, 21, 10);

RunSummary _run({
  required String id,
  String workflowName = 'Pipeline',
  RunStatus status = RunStatus.succeeded,
  DateTime? startedAt,
  String? parentRunId,
  String? parentNodeId,
}) => RunSummary(
  id: id,
  workspaceId: 'ws-1',
  workflowId: 'wf-1',
  workflowName: workflowName,
  status: status,
  startedAt: startedAt ?? _baseTime,
  finishedAt: status.isActive ? null : DateTime.utc(2026, 11, 21, 10, 1),
  checkpointCount: 1,
  parentRunId: parentRunId,
  parentNodeId: parentNodeId,
);

Widget _buildRouterHost(List<String> navigated) {
  final router = GoRouter(
    initialLocation: '/runs',
    routes: <RouteBase>[
      GoRoute(
        path: '/runs',
        builder: (_, _) => const Scaffold(body: RunsPage()),
      ),
      GoRoute(
        path: '/runs/:id',
        builder: (_, state) {
          navigated.add(state.uri.toString());
          return Scaffold(body: Text('detail:${state.pathParameters['id']}'));
        },
      ),
    ],
  );

  return MaterialApp.router(
    theme: HiveTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

void main() {
  group('RunsListController nesting', () {
    test('children whose parent is loaded are not top level', () async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
          _run(id: 'p1'),
          _run(id: 'other'),
        ]);
      final container = ProviderContainer.test(
        overrides: [
          ..._workspaceOverrides(),
          runRepositoryProvider.overrideWithValue(repo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
        ],
      );

      final state = await container.read(runsListControllerProvider.future);
      expect(state.topLevelRuns.map((r) => r.id).toList(), <String>[
        'p1',
        'other',
      ]);
    });

    test('a child whose parent is not loaded stays top level', () async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(
            id: 'orphan',
            parentRunId: 'missing-parent',
            parentNodeId: 'fan',
          ),
          _run(id: 'other'),
        ]);
      final container = ProviderContainer.test(
        overrides: [
          ..._workspaceOverrides(),
          runRepositoryProvider.overrideWithValue(repo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
        ],
      );

      final state = await container.read(runsListControllerProvider.future);
      expect(state.topLevelRuns.map((r) => r.id).toList(), <String>[
        'orphan',
        'other',
      ]);
    });

    test('childrenOf is ordered oldest first', () async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(
            id: 'c2',
            parentRunId: 'p1',
            parentNodeId: 'fan',
            startedAt: DateTime.utc(2026, 11, 21, 10, 2),
          ),
          _run(
            id: 'c1',
            parentRunId: 'p1',
            parentNodeId: 'fan',
            startedAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
          _run(id: 'p1'),
        ]);
      final container = ProviderContainer.test(
        overrides: [
          ..._workspaceOverrides(),
          runRepositoryProvider.overrideWithValue(repo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
        ],
      );

      final state = await container.read(runsListControllerProvider.future);
      expect(state.childrenOf('p1').map((r) => r.id).toList(), <String>[
        'c1',
        'c2',
      ]);
    });

    test('toggleExpanded flips membership and survives refresh()', () async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'p1'),
          _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
        ]);
      final container = ProviderContainer.test(
        overrides: [
          ..._workspaceOverrides(),
          runRepositoryProvider.overrideWithValue(repo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
        ],
      );

      await container.read(runsListControllerProvider.future);
      final notifier = container.read(runsListControllerProvider.notifier)
        ..toggleExpanded('p1');
      expect(
        container.read(runsListControllerProvider).requireValue.expandedRunIds,
        contains('p1'),
      );

      await notifier.refresh();
      expect(
        container.read(runsListControllerProvider).requireValue.expandedRunIds,
        contains('p1'),
      );

      notifier.toggleExpanded('p1');
      expect(
        container.read(runsListControllerProvider).requireValue.expandedRunIds,
        isNot(contains('p1')),
      );
    });

    test(
      'deleteRun of a parent removes its children and fixes total',
      () async {
        final repo = _FakeRunRepository()
          ..items.addAll(<RunSummary>[
            _run(id: 'p1'),
            _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
            _run(id: 'c2', parentRunId: 'p1', parentNodeId: 'fan'),
            _run(id: 'other1'),
            _run(id: 'other2'),
          ]);
        final container = ProviderContainer.test(
          overrides: [
            ..._workspaceOverrides(),
            runRepositoryProvider.overrideWithValue(repo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
          ],
        );

        final initial = await container.read(runsListControllerProvider.future);
        expect(initial.total, 5);

        await container
            .read(runsListControllerProvider.notifier)
            .deleteRun('p1');

        final updated = container.read(runsListControllerProvider).requireValue;
        expect(repo.deletedIds, <String>['p1']);
        expect(updated.runs.map((r) => r.id).toList(), <String>[
          'other1',
          'other2',
        ]);
        expect(updated.total, 2);
      },
    );

    test('deleteRun of a leaf removes only itself', () async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'p1'),
          _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
          _run(id: 'other'),
        ]);
      final container = ProviderContainer.test(
        overrides: [
          ..._workspaceOverrides(),
          runRepositoryProvider.overrideWithValue(repo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
        ],
      );

      await container.read(runsListControllerProvider.future);
      await container.read(runsListControllerProvider.notifier).deleteRun('c1');

      final updated = container.read(runsListControllerProvider).requireValue;
      expect(repo.deletedIds, <String>['c1']);
      expect(updated.runs.map((r) => r.id).toList(), <String>['p1', 'other']);
      expect(updated.total, 2);
    });
  });

  group('RunsPage nesting', () {
    Future<void> pumpRunsPage(
      WidgetTester tester,
      _FakeRunRepository repo, {
      List<String>? navigated,
    }) async {
      tester.view.physicalSize = const Size(1100, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._workspaceOverrides(),
            runRepositoryProvider.overrideWithValue(repo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
          ],
          child: _buildRouterHost(navigated ?? <String>[]),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('parent row shows "2 child runs" and a collapsed toggle', (
      tester,
    ) async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'p1', workflowName: 'Parent Flow'),
          _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
          _run(id: 'c2', parentRunId: 'p1', parentNodeId: 'fan'),
        ]);
      await pumpRunsPage(tester, repo);

      expect(find.byKey(const Key('run_children_count_p1')), findsOneWidget);
      expect(find.text('2 child runs'), findsOneWidget);
      expect(find.byKey(const Key('run_children_toggle_p1')), findsOneWidget);
      expect(find.byKey(const Key('run_card_c1')), findsNothing);
      expect(find.byKey(const Key('run_card_c2')), findsNothing);
    });

    testWidgets('singular copy', (tester) async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'p1'),
          _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
        ]);
      await pumpRunsPage(tester, repo);

      expect(find.text('1 child run'), findsOneWidget);
    });

    testWidgets(
      'tapping the toggle shows the children indented below the parent in '
      'startedAt order',
      (tester) async {
        final repo = _FakeRunRepository()
          ..items.addAll(<RunSummary>[
            _run(
              id: 'c2',
              workflowName: 'Child Two',
              parentRunId: 'p1',
              parentNodeId: 'fan',
              startedAt: DateTime.utc(2026, 11, 21, 10, 2),
            ),
            _run(id: 'p1', workflowName: 'Parent'),
            _run(
              id: 'c1',
              workflowName: 'Child One',
              parentRunId: 'p1',
              parentNodeId: 'fan',
              startedAt: DateTime.utc(2026, 11, 21, 10, 1),
            ),
          ]);
        await pumpRunsPage(tester, repo);

        await tester.tap(find.byKey(const Key('run_children_toggle_p1')));
        await tester.pumpAndSettle();

        final parentPos = tester.getTopLeft(
          find.byKey(const Key('run_card_p1')),
        );
        final c1Pos = tester.getTopLeft(find.byKey(const Key('run_card_c1')));
        final c2Pos = tester.getTopLeft(find.byKey(const Key('run_card_c2')));

        expect(c1Pos.dy, greaterThan(parentPos.dy));
        expect(c2Pos.dy, greaterThan(c1Pos.dy));
        expect(c1Pos.dx, greaterThan(parentPos.dx));
        expect(c2Pos.dx, greaterThan(parentPos.dx));
      },
    );

    testWidgets('tapping a child opens its detail', (tester) async {
      final navigated = <String>[];
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'p1'),
          _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
        ]);
      await pumpRunsPage(tester, repo, navigated: navigated);

      await tester.tap(find.byKey(const Key('run_children_toggle_p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run_card_c1')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/runs/c1']);
    });

    testWidgets('a child has no toggle', (tester) async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'p1'),
          _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
        ]);
      await pumpRunsPage(tester, repo);

      await tester.tap(find.byKey(const Key('run_children_toggle_p1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('run_children_toggle_c1')), findsNothing);
    });

    testWidgets('status of each child is rendered', (tester) async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'p1', status: RunStatus.running),
          _run(
            id: 'c1',
            parentRunId: 'p1',
            parentNodeId: 'fan',
            status: RunStatus.failed,
            startedAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
          _run(
            id: 'c2',
            parentRunId: 'p1',
            parentNodeId: 'fan',
            status: RunStatus.running,
            startedAt: DateTime.utc(2026, 11, 21, 10, 2),
          ),
        ]);
      await pumpRunsPage(tester, repo);

      await tester.tap(find.byKey(const Key('run_children_toggle_p1')));
      await tester.pumpAndSettle();

      expect(find.text('Failed'), findsWidgets);
      expect(find.text('Running'), findsWidgets);
    });
  });
}
