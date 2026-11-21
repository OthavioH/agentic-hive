import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflow_editor_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 20, 12);
  int saveCalls = 0;

  Workflow stored = Workflow(
    id: 'wf-1',
    name: 'Editable Flow',
    nodes: const <WorkflowNode>[],
    edges: const <WorkflowEdge>[],
    createdAt: DateTime.utc(2026, 11, 20, 12),
    updatedAt: DateTime.utc(2026, 11, 20, 12),
  );

  WorkflowValidationResult validation = const WorkflowValidationResult(
    isValid: false,
    issues: <WorkflowValidationIssue>[
      WorkflowValidationIssue(
        severity: WorkflowValidationSeverity.error,
        code: 'empty_nodes',
        message: 'Workflow must contain at least one node.',
      ),
    ],
  );

  @override
  Future<Result<WorkflowResponse>> getWorkflow(String id) async {
    return Success(WorkflowResponse(workflow: stored, validation: validation));
  }

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request,
  ) async {
    saveCalls++;
    stored = stored.copyWith(
      name: request.name,
      description: request.description,
      nodes: request.nodes,
      edges: request.edges,
      entryNodeId: request.entryNodeId,
    );
    validation = const WorkflowValidationResult(isValid: true);
    return Success(WorkflowResponse(workflow: stored, validation: validation));
  }

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async {
    if (workflow.nodes.isNotEmpty) {
      return const Success(WorkflowValidationResult(isValid: true));
    }
    return Success(validation);
  }

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows() async =>
      const Success(<WorkflowSummary>[]);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteWorkflow(String id) async =>
      const Success<void>(null);
}

Widget _buildEditorHost() {
  final router = GoRouter(
    initialLocation: '/workflows/wf-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/workflows',
        builder: (_, _) => const Scaffold(body: Text('WorkflowsList')),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            builder: (_, state) => Scaffold(
              body: WorkflowEditorPage(workflowId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );

  return NodeVisualScope(
    registry: NodeVisualRegistry(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: HiveTheme.dark(),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('WorkflowEditorPage adds node, edits inspector, and saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkflowRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        child: _buildEditorHost(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkflowEditorPage)),
    )!;

    expect(find.text('Editable Flow'), findsWidgets);
    expect(find.text(l10n.editorSavedBadge), findsOneWidget);
    expect(
      find.text('Workflow must contain at least one node.'),
      findsOneWidget,
    );

    // Add node -> becomes dirty, selects node, shows node inspector.
    await tester.tap(find.byKey(const Key('editor_add_node_button')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.editorUnsavedBadge), findsOneWidget);
    expect(find.byKey(const Key('inspector_node_label')), findsOneWidget);
    expect(find.text(l10n.editorEntryBadge), findsOneWidget);

    // Edit node label in inspector.
    await tester.enterText(
      find.byKey(const Key('inspector_node_label')),
      'Plan Step',
    );
    await tester.pumpAndSettle();
    expect(find.text('Plan Step'), findsWidgets);

    // Save workflow.
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    expect(repo.saveCalls, 1);
    expect(find.text(l10n.editorSavedBadge), findsOneWidget);
    expect(find.text(l10n.editorValidationValid), findsOneWidget);
  });

  testWidgets('WorkflowEditorPage prompts before discarding unsaved changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkflowRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        child: _buildEditorHost(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkflowEditorPage)),
    )!;

    await tester.tap(find.byKey(const Key('editor_add_node_button')));
    await tester.pumpAndSettle();

    // Tap back button while dirty -> HiveDialog appears.
    await tester.tap(find.byKey(const Key('editor_back_button')));
    await tester.pumpAndSettle();

    expect(find.byType(HiveDialog), findsOneWidget);
    expect(find.text(l10n.editorUnsavedDialogTitle), findsOneWidget);

    await tester.tap(find.text(l10n.editorDiscardAction));
    await tester.pumpAndSettle();

    expect(find.text('WorkflowsList'), findsOneWidget);
  });
}
