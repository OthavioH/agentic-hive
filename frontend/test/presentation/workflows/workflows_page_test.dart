import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 20, 12);
  final List<WorkflowSummary> items = <WorkflowSummary>[];
  final List<String> deletedIds = <String>[];
  final List<String> duplicatedIds = <String>[];
  Result<List<WorkflowSummary>>? listOverride;

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    String? workspaceId,
  }) async {
    if (listOverride != null) return listOverride!;
    return Success(List<WorkflowSummary>.from(items));
  }

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async {
    final wf = Workflow(
      id: 'wf-new',
      name: request.name,
      description: request.description,
      nodes: const <WorkflowNode>[],
      edges: const <WorkflowEdge>[],
      createdAt: now,
      updatedAt: now,
    );
    items.add(
      WorkflowSummary(
        id: wf.id,
        name: wf.name,
        description: wf.description,
        nodeCount: 0,
        edgeCount: 0,
        hasValidationErrors: true,
        updatedAt: now,
      ),
    );
    return Success(
      WorkflowResponse(
        workflow: wf,
        validation: const WorkflowValidationResult(isValid: false),
      ),
    );
  }

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async {
    duplicatedIds.add(id);
    final source = items.firstWhere((w) => w.id == id);
    final copy = WorkflowSummary(
      id: '$id-copy',
      name: '${source.name} (Copy)',
      nodeCount: source.nodeCount,
      edgeCount: source.edgeCount,
      hasValidationErrors: source.hasValidationErrors,
      updatedAt: now,
    );
    items.add(copy);
    return Success(
      WorkflowResponse(
        workflow: Workflow(
          id: copy.id,
          name: copy.name,
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        validation: const WorkflowValidationResult(isValid: true),
      ),
    );
  }

  Result<void>? deleteOverride;

  @override
  Future<Result<void>> deleteWorkflow(String id, {String? workspaceId}) async {
    if (deleteOverride case final override?) {
      return override;
    }
    deletedIds.add(id);
    items.removeWhere((w) => w.id == id);
    return const Success<void>(null);
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

Widget _buildRouterHost({required List<String> navigatedPaths}) {
  final router = GoRouter(
    initialLocation: '/workflows',
    routes: <RouteBase>[
      GoRoute(
        path: '/workflows',
        builder: (_, _) => const Scaffold(body: WorkflowsPage()),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            builder: (_, state) {
              navigatedPaths.add(state.uri.toString());
              return Scaffold(
                body: Text('Editor:${state.pathParameters['id']}'),
              );
            },
          ),
        ],
      ),
    ],
  );

  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: HiveTheme.dark(),
    routerConfig: router,
  );
}

void main() {
  testWidgets(
    'WorkflowsPage shows empty state and creates workflow via dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeWorkflowRepository();
      final navigated = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
          child: _buildRouterHost(navigatedPaths: navigated),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowsPage)),
      )!;
      expect(find.text(l10n.workflowsEmptyTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('workflows_new_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('create_workflow_name_field')),
        'My Pipeline',
      );
      await tester.tap(find.byKey(const Key('create_workflow_confirm_button')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/workflows/wf-new']);
      expect(find.text('Editor:wf-new'), findsOneWidget);
    },
  );

  testWidgets(
    'WorkflowsPage lists items, filters, duplicates, and confirms delete',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime.utc(2026, 11, 20, 12);
      final repo = _FakeWorkflowRepository()
        ..items.addAll(<WorkflowSummary>[
          WorkflowSummary(
            id: 'wf-1',
            name: 'Release Flow',
            nodeCount: 2,
            edgeCount: 1,
            hasValidationErrors: false,
            updatedAt: now,
          ),
          WorkflowSummary(
            id: 'wf-2',
            name: 'Lint Check',
            nodeCount: 1,
            edgeCount: 0,
            hasValidationErrors: true,
            updatedAt: now,
          ),
        ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
          child: _buildRouterHost(navigatedPaths: <String>[]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Release Flow'), findsOneWidget);
      expect(find.text('Lint Check'), findsOneWidget);

      // Duplicate wf-1
      await tester.tap(find.byKey(const Key('duplicate_workflow_wf-1')));
      await tester.pumpAndSettle();
      expect(repo.duplicatedIds, <String>['wf-1']);
      expect(find.text('Release Flow (Copy)'), findsOneWidget);

      // Search filter
      await tester.enterText(
        find.byKey(const Key('workflows_search_field')),
        'Lint',
      );
      await tester.pumpAndSettle();
      expect(find.text('Lint Check'), findsOneWidget);
      expect(find.text('Release Flow'), findsNothing);

      // Delete wf-2 with HiveDialog confirmation
      await tester.tap(find.byKey(const Key('delete_workflow_wf-2')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowsPage)),
      )!;
      expect(find.byType(HiveDialog), findsOneWidget);
      await tester.tap(find.text(l10n.workflowsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(repo.deletedIds, <String>['wf-2']);
      expect(find.text('Lint Check'), findsNothing);
    },
  );

  testWidgets('WorkflowsPage delete dialog says run history is deleted '
      'and files are kept', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkflowRepository()
      ..items.add(
        WorkflowSummary(
          id: 'wf-1',
          name: 'Release Flow',
          nodeCount: 2,
          edgeCount: 1,
          hasValidationErrors: false,
          updatedAt: DateTime.utc(2026, 11, 20, 12),
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        child: _buildRouterHost(navigatedPaths: <String>[]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkflowsPage)),
    )!;
    final message = l10n.workflowsDeleteMessage('Release Flow');
    expect(find.text(message), findsOneWidget);
    expect(message, contains('run history is deleted too'));
    expect(message, contains('Files and worktrees are kept'));
  });

  testWidgets(
    'WorkflowsPage shows the active-runs message when delete is refused',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeWorkflowRepository()
        ..items.add(
          WorkflowSummary(
            id: 'wf-1',
            name: 'Release Flow',
            nodeCount: 2,
            edgeCount: 1,
            hasValidationErrors: false,
            updatedAt: DateTime.utc(2026, 11, 20, 12),
          ),
        )
        ..deleteOverride = const FailureResult(
          BackendFailure(
            'x',
            code: ApiErrorCode.workflowHasActiveRuns,
            statusCode: 409,
          ),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
          child: _buildRouterHost(navigatedPaths: <String>[]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowsPage)),
      )!;
      await tester.tap(find.text(l10n.workflowsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.workflowsFailureActiveRuns), findsOneWidget);
      expect(find.text('Release Flow'), findsOneWidget);
    },
  );
}
