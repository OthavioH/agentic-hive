import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_reference_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_reference_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'scripted_workflow_repository.dart';

final class _FakeWorkflowReferenceRepository
    implements WorkflowReferenceRepository {
  Result<List<WorkflowReference>> nextResult = const Success(
    <WorkflowReference>[],
  );
  final List<({String workflowId, String? workspaceId})> calls =
      <({String workflowId, String? workspaceId})>[];

  @override
  Future<Result<List<WorkflowReference>>> getReferences(
    String workflowId, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    calls.add((workflowId: workflowId, workspaceId: scope.workspaceIdOrNull));
    return nextResult;
  }
}

WorkflowSummary _workflow({
  String id = 'wf-1',
  String name = 'Child Flow',
  DefinitionScope scope = const GlobalScope(),
}) => WorkflowSummary(
  id: id,
  name: name,
  scope: scope,
  nodeCount: 2,
  edgeCount: 1,
  hasValidationErrors: false,
  updatedAt: DateTime.utc(2026, 11, 20, 12),
  revision: 'r1',
);

Future<void> _pump(
  WidgetTester tester,
  ScriptedWorkflowRepository repo,
  _FakeWorkflowReferenceRepository refRepo,
) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    for (final controller in repo.live) {
      await controller.close();
    }
  });

  final router = GoRouter(
    initialLocation: '/workflows',
    routes: <RouteBase>[
      GoRoute(
        path: '/workflows',
        builder: (_, _) => const Scaffold(body: WorkflowsPage()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workflowRepositoryProvider.overrideWithValue(repo),
        workflowReferenceRepositoryProvider.overrideWithValue(refRepo),
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
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(WorkflowsPage)))!;

void main() {
  testWidgets('delete confirmation lists the referencing workflows', (
    tester,
  ) async {
    final repo = ScriptedWorkflowRepository()..items.add(_workflow());
    final refRepo = _FakeWorkflowReferenceRepository()
      ..nextResult = const Success(<WorkflowReference>[
        WorkflowReference(
          workflowId: 'wf-p',
          workflowName: 'Planner',
          nodeIds: <String>['n1'],
        ),
        WorkflowReference(
          workflowId: 'wf-r',
          workflowName: 'Release',
          nodeIds: <String>['n2'],
        ),
      ]);
    await _pump(tester, repo, refRepo);

    await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(
      find.textContaining('Used by fan-out nodes in: Planner, Release'),
      findsOneWidget,
    );
    expect(
      find.textContaining(l10n.workflowsDeleteMessage('Child Flow')),
      findsOneWidget,
    );
  });

  testWidgets('duplicates are listed once', (tester) async {
    final repo = ScriptedWorkflowRepository()..items.add(_workflow());
    final refRepo = _FakeWorkflowReferenceRepository()
      ..nextResult = const Success(<WorkflowReference>[
        WorkflowReference(
          workflowId: 'wf-p1',
          workflowName: 'Planner',
          nodeIds: <String>['n1'],
        ),
        WorkflowReference(
          workflowId: 'wf-p2',
          workflowName: 'Planner',
          scope: WorkspaceScope('ws-1'),
          nodeIds: <String>['n2'],
        ),
      ]);
    await _pump(tester, repo, refRepo);

    await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Used by fan-out nodes in: Planner'),
      findsOneWidget,
    );
    expect(find.textContaining('Planner, Planner'), findsNothing);
  });

  testWidgets('no references leaves the dialog unchanged', (tester) async {
    final repo = ScriptedWorkflowRepository()..items.add(_workflow());
    final refRepo = _FakeWorkflowReferenceRepository();
    await _pump(tester, repo, refRepo);

    await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(
      find.text(l10n.workflowsDeleteMessage('Child Flow')),
      findsOneWidget,
    );
    expect(find.textContaining('Used by fan-out nodes'), findsNothing);
  });

  testWidgets(
    'a failing lookup leaves the dialog unchanged and does not block',
    (tester) async {
      final repo = ScriptedWorkflowRepository()
        ..items.add(_workflow())
        ..scripts.add(<WorkflowDeletionUpdate>[
          const WorkflowDeletionStarted(operationId: 'op-1'),
          const WorkflowDeletionSucceeded(),
        ]);
      final refRepo = _FakeWorkflowReferenceRepository()
        ..nextResult = const FailureResult<List<WorkflowReference>>(
          NetworkFailure('offline'),
        );
      await _pump(tester, repo, refRepo);

      await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
      await tester.pumpAndSettle();

      final l10n = _l10n(tester);
      expect(
        find.text(l10n.workflowsDeleteMessage('Child Flow')),
        findsOneWidget,
      );
      expect(find.textContaining('Used by fan-out nodes'), findsNothing);

      await tester.tap(find.text(l10n.workflowsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls.single.id, 'wf-1');
    },
  );

  testWidgets("the lookup is scoped to the workflow's workspace", (
    tester,
  ) async {
    final repo = ScriptedWorkflowRepository()
      ..items.add(_workflow(scope: const WorkspaceScope('ws-42')));
    final refRepo = _FakeWorkflowReferenceRepository();
    await _pump(tester, repo, refRepo);

    await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
    await tester.pumpAndSettle();

    expect(refRepo.calls, <({String workflowId, String? workspaceId})>[
      (workflowId: 'wf-1', workspaceId: 'ws-42'),
    ]);
  });
}
