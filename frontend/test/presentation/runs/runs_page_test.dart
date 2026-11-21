import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeRunRepository implements RunRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);
  final List<RunSummary> items = <RunSummary>[];
  final List<String> deletedIds = <String>[];

  void seedMixed() {
    items
      ..clear()
      ..addAll(<RunSummary>[
        RunSummary(
          id: 'run-active',
          workflowId: 'wf-1',
          workflowName: 'Active Pipeline',
          status: RunStatus.running,
          startedAt: now,
          checkpointCount: 1,
        ),
        RunSummary(
          id: 'run-done',
          workflowId: 'wf-2',
          workflowName: 'Completed Pipeline',
          status: RunStatus.succeeded,
          startedAt: now,
          finishedAt: DateTime.utc(2026, 11, 21, 4, 30, 42),
          checkpointCount: 3,
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
    final filtered = items.where((run) {
      if (status != null && run.status != status) return false;
      if (workflowId != null && run.workflowId != workflowId) return false;
      return true;
    }).toList();
    return Success(RunsListResponse(items: filtered, total: filtered.length));
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
  Future<Result<void>> deleteRun(String id) async {
    deletedIds.add(id);
    items.removeWhere((run) => run.id == id);
    return const Success(null);
  }
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows() async =>
      Success(<WorkflowSummary>[
        WorkflowSummary(
          id: 'wf-1',
          name: 'Active Pipeline',
          nodeCount: 1,
          edgeCount: 0,
          hasValidationErrors: false,
          updatedAt: now,
        ),
        WorkflowSummary(
          id: 'wf-2',
          name: 'Completed Pipeline',
          nodeCount: 2,
          edgeCount: 1,
          hasValidationErrors: false,
          updatedAt: now,
        ),
      ]);

  @override
  Future<Result<WorkflowResponse>> getWorkflow(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteWorkflow(String id) async => const Success(null);

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

Widget _buildRouterHost() {
  final router = GoRouter(
    initialLocation: '/runs',
    routes: <RouteBase>[
      GoRoute(
        path: '/runs',
        builder: (_, _) => const Scaffold(body: RunsPage()),
      ),
      GoRoute(
        path: '/runs/:id',
        builder: (_, state) =>
            Scaffold(body: Text('detail:${state.pathParameters['id']}')),
      ),
    ],
  );

  return MaterialApp.router(
    theme: HiveTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  testWidgets('renders empty state when no runs exist', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeRunRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
        ],
        child: _buildRouterHost(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(RunsPage)))!;
    expect(find.text(l10n.runsEmptyTitle), findsOneWidget);
  });

  testWidgets(
    'renders runs list, filters by status, and hides delete on active runs',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeRunRepository()..seedMixed();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(repo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
          ],
          child: _buildRouterHost(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Pipeline'), findsOneWidget);
      expect(find.text('Completed Pipeline'), findsOneWidget);
      expect(find.byKey(const Key('run_delete_run-active')), findsNothing);
      expect(find.byKey(const Key('run_delete_run-done')), findsOneWidget);

      await tester.tap(find.byKey(const Key('runs_filter_succeeded')));
      await tester.pumpAndSettle();
      expect(find.text('Active Pipeline'), findsNothing);
      expect(find.text('Completed Pipeline'), findsOneWidget);

      await tester.tap(find.byKey(const Key('runs_filter_failed')));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(RunsPage)))!;
      expect(find.text(l10n.runsFilterEmptyTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('runs_clear_filters_button')));
      await tester.pumpAndSettle();
      expect(find.text('Active Pipeline'), findsOneWidget);
      expect(find.text('Completed Pipeline'), findsOneWidget);
    },
  );

  testWidgets(
    'confirms delete with HiveDialog before deleting non-active run',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeRunRepository()..seedMixed();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(repo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
          ],
          child: _buildRouterHost(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('run_delete_run-done')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(RunsPage)))!;
      expect(find.text(l10n.runsDeleteTitle), findsOneWidget);

      await tester.tap(find.text(l10n.runsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(repo.deletedIds, <String>['run-done']);
      expect(find.text('Completed Pipeline'), findsNothing);
      expect(find.text('Active Pipeline'), findsOneWidget);
    },
  );
}
