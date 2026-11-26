import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../workspace/fake_workspace_repository.dart';

final class _ScopedRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 20, 12);
  late List<WorkflowSummary> items;
  final List<String?> deletedScopes = <String?>[];
  final List<String?> duplicatedScopes = <String?>[];
  final List<String?> createdScopes = <String?>[];

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async => Success(
    items.where((w) => w.scope is GlobalScope || w.scope == scope).toList(),
  );

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async {
    createdScopes.add(request.workspaceId);
    return Success(
      WorkflowResponse(
        workflow: Workflow(
          id: 'wf-new',
          name: request.name,
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        validation: const WorkflowValidationResult(isValid: false),
        scope: DefinitionScope.ofWorkspaceId(request.workspaceId),
      ),
    );
  }

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  }) async {
    duplicatedScopes.add(scope.workspaceIdOrNull);
    return const FailureResult(NotFoundFailure('unused'));
  }

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) {
    final workspaceId = scope.workspaceIdOrNull;
    deletedScopes.add(workspaceId);
    items.removeWhere(
      (w) => w.id == id && w.scope.workspaceIdOrNull == workspaceId,
    );
    return Stream.value(const WorkflowDeletionSucceeded());
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

final class _MemorySelectionStore implements WorkspaceSelectionStore {
  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String? workspaceId) async {}
}

WorkflowSummary _summary(String id, String name, {String? workspaceId}) =>
    WorkflowSummary(
      id: id,
      name: name,
      nodeCount: 1,
      edgeCount: 0,
      hasValidationErrors: false,
      updatedAt: DateTime.utc(2026, 11, 20, 12),
      scope: DefinitionScope.ofWorkspaceId(workspaceId),
    );

Future<_ScopedRepository> _pump(
  WidgetTester tester, {
  required List<String> navigated,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _ScopedRepository()
    ..items = <WorkflowSummary>[
      _summary('global-id', 'Release'),
      _summary('release', 'Release', workspaceId: 'ws-1'),
    ];
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
              navigated.add(state.uri.toString());
              return const Scaffold(body: Text('Editor'));
            },
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workflowRepositoryProvider.overrideWithValue(repo),
        workspaceRepositoryProvider.overrideWithValue(
          FakeWorkspaceRepository(workspaces: [makeWorkspace(name: 'One')]),
        ),
        workspaceSelectionStoreProvider.overrideWithValue(
          _MemorySelectionStore(),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: HiveTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('same-named workflows of both scopes are listed with badges', (
    tester,
  ) async {
    await _pump(tester, navigated: <String>[]);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkflowsPage)),
    )!;

    expect(find.text('Release'), findsNWidgets(2));
    expect(find.text(l10n.workflowsScopeWorkspaceBadge), findsOneWidget);
    expect(find.text(l10n.workflowsScopeGlobalBadge), findsOneWidget);
  });

  testWidgets('delete and duplicate address the scope of the item', (
    tester,
  ) async {
    final repo = await _pump(tester, navigated: <String>[]);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkflowsPage)),
    )!;

    await tester.tap(find.byKey(const Key('duplicate_workflow_release')));
    await tester.pumpAndSettle();
    expect(repo.duplicatedScopes, <String?>['ws-1']);

    await tester.tap(find.byKey(const Key('delete_workflow_release')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.workflowsDeleteConfirm));
    await tester.pumpAndSettle();
    expect(repo.deletedScopes, <String?>['ws-1']);
    expect(find.text('Release'), findsOneWidget);
  });

  testWidgets('opening a workspace workflow carries its workspace id', (
    tester,
  ) async {
    final navigated = <String>[];
    await _pump(tester, navigated: navigated);

    await tester.tap(find.byKey(const Key('workflow_card_release')));
    await tester.pumpAndSettle();

    expect(navigated, <String>['/workflows/release?workspace-id=ws-1']);
  });

  for (final global in <bool>[false, true]) {
    testWidgets(
      'create ${global ? 'in Global scope when chosen' : 'defaults to the '
                'current workspace'}',
      (tester) async {
        final repo = await _pump(tester, navigated: <String>[]);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(WorkflowsPage)),
        )!;

        await tester.tap(find.byKey(const Key('workflows_new_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('create_workflow_name_field')),
          'New',
        );
        if (global) {
          await tester.tap(
            find.descendant(
              of: find.byType(HiveDialog),
              matching: find.text(l10n.workflowsScopeGlobalBadge),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.byKey(const Key('create_workflow_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(repo.createdScopes, <String?>[if (global) null else 'ws-1']);
      },
    );
  }
}
