import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../workspace/fake_workspace_repository.dart';
import '../workspace/fake_workspace_settings_repository.dart';

final class _FakeRunRepository implements RunRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);
  StartRunRequest? lastStartRequest;
  Result<Run>? startOverride;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

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
  Future<Result<Run>> startRun(StartRunRequest request) async {
    lastStartRequest = request;
    if (startOverride != null) return startOverride!;
    return Success(
      Run(
        id: 'run-new',
        workflowId: request.workflowId,
        workflowName: 'Release Build',
        workflowDefinition: Workflow(
          id: request.workflowId,
          name: 'Release Build',
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        workspacePath: '/projects/hive',
        workspaceId: request.workspaceId,
        status: RunStatus.running,
        startedAt: now,
        isolationMode:
            request.workspaceIsolationMode ?? WorkspaceIsolationMode.direct,
      ),
    );
  }

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
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);

  /// Workspace ids passed to [listWorkflows], in call order.
  final List<String?> listedWorkspaceIds = <String?>[];

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    String? workspaceId,
  }) async {
    listedWorkspaceIds.add(workspaceId);
    return Success(<WorkflowSummary>[
      WorkflowSummary(
        id: 'wf-1',
        name: 'Release Build',
        nodeCount: 2,
        edgeCount: 1,
        hasValidationErrors: false,
        updatedAt: now,
      ),
      if (workspaceId == 'ws-2')
        WorkflowSummary(
          id: 'wf-ws-2',
          name: 'Ticket Implementation',
          nodeCount: 9,
          edgeCount: 11,
          hasValidationErrors: false,
          updatedAt: now,
        ),
    ]);
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    String? workspaceId,
    String? revision,
    bool force = false,
  }) => Stream.value(const WorkflowDeletionSucceeded());

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

void main() {
  testWidgets(
    'StartRunDialog offers primary, existing worktree, and new worktree',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runsRepo = _FakeRunRepository();
      final workspaceRepo =
          FakeWorkspaceRepository(
              workspaces: <Workspace>[
                makeWorkspace(rootPath: '/projects/hive'),
                makeWorkspace(
                  id: 'ws-2',
                  name: 'Second',
                  rootPath: '/projects/two',
                ),
              ],
              capabilities: const Success(
                WorkspaceCapabilities(
                  gitAvailable: true,
                  isGitRepo: true,
                  hasCommits: true,
                ),
              ),
            )
            ..worktreesByWorkspaceId['ws-1'] = <Worktree>[
              makeWorktree(),
              makeWorktree(
                id: 'feat-ui',
                name: 'feat-ui',
                path: '/worktrees/ws-1/feat-ui',
                isPrimary: false,
                branch: 'feature/ui',
              ),
            ];

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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runsRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
          ],
          child: MaterialApp.router(
            theme: HiveTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('runs_new_button')));
      await tester.pumpAndSettle();

      expect(find.byType(StartRunDialog), findsOneWidget);
      expect(find.byKey(const Key('start_run_target_primary')), findsOneWidget);
      expect(
        find.byKey(const Key('start_run_target_existing_worktree')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('start_run_target_new_worktree')),
        findsOneWidget,
      );

      // Existing worktree target.
      await tester.tap(
        find.byKey(const Key('start_run_target_existing_worktree')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('start_run_worktree_select')),
        findsOneWidget,
      );

      // New worktree target with branch name.
      await tester.tap(find.byKey(const Key('start_run_target_new_worktree')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('start_run_branch_field')),
        'feature/login',
      );
      await tester.enterText(
        find.byKey(const Key('start_run_input_field')),
        'Audit all handlers',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(runsRepo.lastStartRequest?.workflowId, 'wf-1');
      expect(runsRepo.lastStartRequest?.workspaceId, 'ws-1');
      expect(runsRepo.lastStartRequest?.input, 'Audit all handlers');
      expect(
        runsRepo.lastStartRequest?.target,
        const RunTarget.newWorktree(branch: 'feature/login'),
      );
      expect(find.text('detail:run-new'), findsOneWidget);
    },
  );

  testWidgets(
    'StartRunDialog preselects existing worktree from initialWorktreeId',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runsRepo = _FakeRunRepository();
      final workspaceRepo =
          FakeWorkspaceRepository(
              workspaces: <Workspace>[
                makeWorkspace(rootPath: '/projects/hive'),
              ],
            )
            ..worktreesByWorkspaceId['ws-1'] = <Worktree>[
              makeWorktree(),
              makeWorktree(
                id: 'feat-ui',
                name: 'feat-ui',
                path: '/worktrees/ws-1/feat-ui',
                isPrimary: false,
                branch: 'feature/ui',
              ),
            ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runsRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
          ],
          child: MaterialApp(
            theme: HiveTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: HiveButton(
                  label: 'Open',
                  onPressed: () => StartRunDialog.show(
                    context,
                    initialWorkspaceId: 'ws-1',
                    initialWorktreeId: 'feat-ui',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(
        runsRepo.lastStartRequest?.target,
        const RunTarget.worktree(worktreeId: 'feat-ui'),
      );
    },
  );

  testWidgets(
    'StartRunDialog hides worktrees for non-git workspace and surfaces 409',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runsRepo = _FakeRunRepository()
        ..startOverride = const FailureResult(
          BackendFailure('Conflict', statusCode: 409),
        );
      final workspaceRepo = FakeWorkspaceRepository(
        workspaces: <Workspace>[
          makeWorkspace(rootPath: '/projects/hive', isGit: false),
          makeWorkspace(id: 'ws-2', name: 'Second', rootPath: '/projects/two'),
        ],
        capabilities: const Success(
          WorkspaceCapabilities(
            gitAvailable: true,
            isGitRepo: false,
            hasCommits: false,
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runsRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
          ],
          child: MaterialApp(
            theme: HiveTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: HiveButton(
                  label: 'Open',
                  onPressed: () => StartRunDialog.show(context),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('start_run_target_primary')), findsNothing);
      expect(
        find.byKey(const Key('start_run_target_existing_worktree')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('start_run_target_new_worktree')),
        findsNothing,
      );
      expect(find.byKey(const Key('start_run_non_git_banner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(runsRepo.lastStartRequest?.target, const RunTarget.primary());
      expect(find.byKey(const Key('start_run_error_banner')), findsOneWidget);
      expect(
        find.textContaining('A direct run is already active'),
        findsOneWidget,
      );
    },
  );

  testWidgets('StartRunDialog preselects initialWorkspaceId and sends it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final runsRepo = _FakeRunRepository();
    final workspaceRepo = FakeWorkspaceRepository(
      workspaces: <Workspace>[
        makeWorkspace(rootPath: '/projects/hive'),
        makeWorkspace(id: 'ws-2', name: 'Second', rootPath: '/projects/two'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(runsRepo),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
          workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
        ],
        child: MaterialApp(
          theme: HiveTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: HiveButton(
                label: 'Open',
                onPressed: () =>
                    StartRunDialog.show(context, initialWorkspaceId: 'ws-2'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start_run_confirm_button')));
    await tester.pumpAndSettle();

    expect(runsRepo.lastStartRequest?.workspaceId, 'ws-2');
    expect(workspaceRepo.capabilityPaths, contains('/projects/two'));
  });

  testWidgets('StartRunDialog lists and preselects a workspace workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final runsRepo = _FakeRunRepository();
    final workflowRepo = _FakeWorkflowRepository();
    final workspaceRepo = FakeWorkspaceRepository(
      workspaces: <Workspace>[
        makeWorkspace(rootPath: '/projects/hive'),
        makeWorkspace(id: 'ws-2', name: 'Second', rootPath: '/projects/two'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(runsRepo),
          workflowRepositoryProvider.overrideWithValue(workflowRepo),
          workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
        ],
        child: MaterialApp(
          theme: HiveTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: HiveButton(
                label: 'Open',
                onPressed: () => StartRunDialog.show(
                  context,
                  initialWorkspaceId: 'ws-2',
                  initialWorkflowId: 'wf-ws-2',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(workflowRepo.listedWorkspaceIds, contains('ws-2'));
    expect(find.text('Ticket Implementation'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start_run_confirm_button')));
    await tester.pumpAndSettle();

    expect(runsRepo.lastStartRequest?.workflowId, 'wf-ws-2');
    expect(runsRepo.lastStartRequest?.workspaceId, 'ws-2');
  });

  testWidgets('StartRunDialog warns and disables start with no workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(_FakeRunRepository()),
          workflowRepositoryProvider.overrideWithValue(
            _FakeWorkflowRepository(),
          ),
          workspaceRepositoryProvider.overrideWithValue(
            FakeWorkspaceRepository(),
          ),
        ],
        child: MaterialApp(
          theme: HiveTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: HiveButton(
                label: 'Open',
                onPressed: () => StartRunDialog.show(context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('start_run_no_workspaces_banner')),
      findsOneWidget,
    );
    final confirm = tester.widget<HiveButton>(
      find.byKey(const Key('start_run_confirm_button')),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets(
    'StartRunDialog disables existing worktree chip when none exist',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runsRepo = _FakeRunRepository();
      final workspaceRepo = FakeWorkspaceRepository(
        workspaces: <Workspace>[makeWorkspace(rootPath: '/projects/hive')],
      )..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runsRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
          ],
          child: MaterialApp(
            theme: HiveTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: HiveButton(
                  label: 'Open',
                  onPressed: () => StartRunDialog.show(context),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final existingChip = tester.widget<HiveFilterChip>(
        find.byKey(const Key('start_run_target_existing_worktree')),
      );
      expect(existingChip.onSelected, isNull);

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(runsRepo.lastStartRequest?.target, const RunTarget.primary());
    },
  );

  group('default target from the effective settings', () {
    Future<_FakeRunRepository> openDialog(
      WidgetTester tester, {
      required FakeWorkspaceSettingsRepository settings,
      String? initialWorktreeId,
      bool isGit = true,
    }) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runsRepo = _FakeRunRepository();
      final workspaceRepo =
          FakeWorkspaceRepository(
              workspaces: <Workspace>[
                makeWorkspace(rootPath: '/projects/hive', isGit: isGit),
              ],
            )
            ..worktreesByWorkspaceId['ws-1'] = <Worktree>[
              makeWorktree(),
              makeWorktree(
                id: 'feat-ui',
                name: 'feat-ui',
                path: '/worktrees/ws-1/feat-ui',
                isPrimary: false,
                branch: 'feature/ui',
              ),
            ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runsRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
            workspaceSettingsRepositoryProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            theme: HiveTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: HiveButton(
                  label: 'Open',
                  onPressed: () => StartRunDialog.show(
                    context,
                    initialWorktreeId: initialWorktreeId,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return runsRepo;
    }

    bool chipSelected(WidgetTester tester, String key) =>
        tester.widget<HiveFilterChip>(find.byKey(Key(key))).selected;

    testWidgets('worktree mode preselects a new worktree in a git workspace', (
      tester,
    ) async {
      final settings = FakeWorkspaceSettingsRepository();
      final runsRepo = await openDialog(tester, settings: settings);

      expect(settings.getCalls, <String>['ws-1']);
      expect(chipSelected(tester, 'start_run_target_new_worktree'), isTrue);
      expect(chipSelected(tester, 'start_run_target_primary'), isFalse);

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(runsRepo.lastStartRequest?.target, const RunTarget.newWorktree());
      expect(runsRepo.lastStartRequest?.workspaceIsolationMode, isNull);
    });

    testWidgets('direct mode preselects the primary checkout', (tester) async {
      final settings = FakeWorkspaceSettingsRepository(
        global: const EffectiveExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.direct,
          ignorePatterns: <String>[],
          defaultShell: 'cmd.exe',
        ),
      );
      final runsRepo = await openDialog(tester, settings: settings);

      expect(chipSelected(tester, 'start_run_target_primary'), isTrue);

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(runsRepo.lastStartRequest?.target, const RunTarget.primary());
      expect(runsRepo.lastStartRequest?.workspaceIsolationMode, isNull);
    });

    testWidgets('a per-workspace override wins over the global default', (
      tester,
    ) async {
      final settings = FakeWorkspaceSettingsRepository(
        overrides: const ExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.direct,
        ),
      );
      await openDialog(tester, settings: settings);

      expect(chipSelected(tester, 'start_run_target_primary'), isTrue);
    });

    testWidgets('the tree context still wins over the worktree default', (
      tester,
    ) async {
      final settings = FakeWorkspaceSettingsRepository();
      final runsRepo = await openDialog(
        tester,
        settings: settings,
        initialWorktreeId: primaryWorktreeId,
      );

      expect(chipSelected(tester, 'start_run_target_primary'), isTrue);

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(runsRepo.lastStartRequest?.target, const RunTarget.primary());
    });

    testWidgets('falls back to the primary checkout when settings fail', (
      tester,
    ) async {
      final settings = FakeWorkspaceSettingsRepository()
        ..getFailure = const BackendFailure('boom');
      await openDialog(tester, settings: settings);

      expect(chipSelected(tester, 'start_run_target_primary'), isTrue);
    });

    testWidgets('a non-git workspace runs in the primary checkout', (
      tester,
    ) async {
      final settings = FakeWorkspaceSettingsRepository();
      final runsRepo = await openDialog(
        tester,
        settings: settings,
        isGit: false,
      );

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(runsRepo.lastStartRequest?.target, const RunTarget.primary());
    });
  });
}
