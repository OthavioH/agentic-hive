import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_frontend/core/attachments/attachment_input_source.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_attachment_drafts.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_attachment_input_source.dart';
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
            attachmentInputSourceProvider.overrideWithValue(
              FakeAttachmentInputSource(),
            ),
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
            attachmentInputSourceProvider.overrideWithValue(
              FakeAttachmentInputSource(),
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
            attachmentInputSourceProvider.overrideWithValue(
              FakeAttachmentInputSource(),
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
          attachmentInputSourceProvider.overrideWithValue(
            FakeAttachmentInputSource(),
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
          attachmentInputSourceProvider.overrideWithValue(
            FakeAttachmentInputSource(),
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
          attachmentInputSourceProvider.overrideWithValue(
            FakeAttachmentInputSource(),
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
            attachmentInputSourceProvider.overrideWithValue(
              FakeAttachmentInputSource(),
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
            attachmentInputSourceProvider.overrideWithValue(
              FakeAttachmentInputSource(),
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

  group('attachments', () {
    Uint8List pngBytes([int totalLength = 128]) => Uint8List(totalLength)
      ..setAll(0, const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    Uint8List pdfBytes() => Uint8List.fromList(utf8.encode('%PDF-1.7\n'));

    Future<
      ({_FakeRunRepository runsRepo, FakeAttachmentInputSource inputSource})
    >
    openAttachmentDialog(
      WidgetTester tester, {
      _FakeRunRepository? runsRepo,
    }) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = runsRepo ?? _FakeRunRepository();
      final inputSource = FakeAttachmentInputSource();
      addTearDown(inputSource.dispose);

      final workspaceRepo = FakeWorkspaceRepository(
        workspaces: <Workspace>[makeWorkspace(rootPath: '/projects/hive')],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(repo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
            workspaceSettingsRepositoryProvider.overrideWithValue(
              FakeWorkspaceSettingsRepository(),
            ),
            attachmentInputSourceProvider.overrideWithValue(inputSource),
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
      return (runsRepo: repo, inputSource: inputSource);
    }

    Future<void> pasteShortcut(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('start_run_input_field')));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+V pastes clipboard image and increments pasted index', (
      tester,
    ) async {
      final ctx = await openAttachmentDialog(tester);
      ctx.inputSource.clipboardImage = pngBytes(512);

      await pasteShortcut(tester);
      expect(find.text('Pasted image 1.png · 0.5 KB'), findsOneWidget);

      await pasteShortcut(tester);
      expect(find.text('Pasted image 2.png · 0.5 KB'), findsOneWidget);
    });

    testWidgets(
      'long attachment chip name shows full label in a tooltip on hover',
      (tester) async {
        final ctx = await openAttachmentDialog(tester);
        const longName =
            'very-long-attachment-file-name-for-desktop-builds-final-v2.png';
        ctx.inputSource.emit(
          AttachmentFilesDropped(<RunAttachmentCandidate>[
            RunAttachmentCandidate(
              fileName: longName,
              bytes: pngBytes(512),
              sizeBytes: 512,
            ),
          ]),
        );
        await tester.pumpAndSettle();

        final chipFinder = find.byKey(const Key('start_run_attachment_chip_0'));
        expect(chipFinder, findsOneWidget);
        final tooltipFinder = find.descendant(
          of: chipFinder,
          matching: find.byType(Tooltip),
        );
        expect(tooltipFinder, findsOneWidget);
        const expectedLabel = '$longName · 0.5 KB';
        expect(tester.widget<Tooltip>(tooltipFinder).message, expectedLabel);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();
        await gesture.moveTo(tester.getCenter(chipFinder));
        await tester.pump(tester.element(chipFinder).hiveMotion.long);
        await tester.pump();

        expect(find.text(expectedLabel), findsWidgets);
      },
    );

    testWidgets('drag enter, exit, and drop update drop caption and chips', (
      tester,
    ) async {
      final ctx = await openAttachmentDialog(tester);

      ctx.inputSource.emit(AttachmentDragEntered());
      await tester.pumpAndSettle();
      expect(find.text('Drop images to attach'), findsOneWidget);
      expect(
        tester.widget<HiveDropZone>(find.byType(HiveDropZone)).active,
        isTrue,
      );

      ctx.inputSource.emit(AttachmentDragExited());
      await tester.pumpAndSettle();
      expect(
        tester.widget<HiveDropZone>(find.byType(HiveDropZone)).active,
        isFalse,
      );

      ctx.inputSource.emit(AttachmentDragEntered());
      await tester.pump();
      ctx.inputSource.emit(
        AttachmentFilesDropped(<RunAttachmentCandidate>[
          RunAttachmentCandidate(
            fileName: 'a.png',
            sizeBytes: 1024,
            bytes: pngBytes(1024),
          ),
          RunAttachmentCandidate(
            fileName: 'b.png',
            sizeBytes: 2048,
            bytes: pngBytes(2048),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<HiveDropZone>(find.byType(HiveDropZone)).active,
        isFalse,
      );
      expect(find.text('a.png · 1.0 KB'), findsOneWidget);
      expect(find.text('b.png · 2.0 KB'), findsOneWidget);
    });

    testWidgets('tapping remove button removes attachment chip', (
      tester,
    ) async {
      final ctx = await openAttachmentDialog(tester);

      ctx.inputSource.emit(
        AttachmentFilesDropped(<RunAttachmentCandidate>[
          RunAttachmentCandidate(
            fileName: 'a.png',
            sizeBytes: 1024,
            bytes: pngBytes(1024),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('a.png · 1.0 KB'), findsOneWidget);

      final removeFinder = find.bySemanticsLabel('Remove a.png');
      await tester.ensureVisible(removeFinder);
      await tester.tap(removeFinder);
      await tester.pumpAndSettle();
      expect(find.text('a.png · 1.0 KB'), findsNothing);
    });

    testWidgets('non-image drop shows type error banner and adds no chip', (
      tester,
    ) async {
      final ctx = await openAttachmentDialog(tester);

      ctx.inputSource.emit(
        AttachmentFilesDropped(<RunAttachmentCandidate>[
          RunAttachmentCandidate(
            fileName: 'notes.pdf',
            sizeBytes: pdfBytes().length,
            bytes: pdfBytes(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('start_run_attachment_error_banner')),
        findsOneWidget,
      );
      expect(
        find.text('notes.pdf is not a PNG, JPEG, WebP or GIF image.'),
        findsOneWidget,
      );
      expect(find.byType(HiveRemovableChip), findsNothing);
    });

    testWidgets('enforces count, per-file, and total size limits', (
      tester,
    ) async {
      final ctx = await openAttachmentDialog(tester);

      // 11 files -> 10 chips + limit banner
      ctx.inputSource.emit(
        AttachmentFilesDropped(<RunAttachmentCandidate>[
          for (var i = 0; i < 11; i++)
            RunAttachmentCandidate(
              fileName: 'img_$i.png',
              sizeBytes: 128,
              bytes: pngBytes(),
            ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HiveRemovableChip), findsNWidgets(10));
      expect(
        find.text(
          'You can attach up to 10 images, 10 MB each and 25 MB in total.',
        ),
        findsOneWidget,
      );

      // Clear all 10 chips and test oversize single file (null bytes)
      for (var i = 0; i < 10; i++) {
        final removeFinder = find.bySemanticsLabel('Remove img_$i.png');
        await tester.ensureVisible(removeFinder);
        await tester.tap(removeFinder);
        await tester.pumpAndSettle();
      }
      ctx.inputSource.emit(
        AttachmentFilesDropped(<RunAttachmentCandidate>[
          const RunAttachmentCandidate(
            fileName: 'huge.png',
            sizeBytes: RunAttachmentLimits.maxBytesEach + 1,
            bytes: null,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HiveRemovableChip), findsNothing);
      expect(
        find.byKey(const Key('start_run_attachment_error_banner')),
        findsOneWidget,
      );

      // Total > 25 MiB rejects overflow
      final nineMb = pngBytes(9 * 1024 * 1024);
      ctx.inputSource.emit(
        AttachmentFilesDropped(<RunAttachmentCandidate>[
          RunAttachmentCandidate(
            fileName: 'one.png',
            sizeBytes: nineMb.length,
            bytes: nineMb,
          ),
          RunAttachmentCandidate(
            fileName: 'two.png',
            sizeBytes: nineMb.length,
            bytes: nineMb,
          ),
          RunAttachmentCandidate(
            fileName: 'three.png',
            sizeBytes: nineMb.length,
            bytes: nineMb,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HiveRemovableChip), findsNWidgets(2));
      expect(
        find.byKey(const Key('start_run_attachment_error_banner')),
        findsOneWidget,
      );
    });

    testWidgets('partial drop accepts valid files and shows error banner', (
      tester,
    ) async {
      final ctx = await openAttachmentDialog(tester);

      ctx.inputSource.emit(
        AttachmentFilesDropped(<RunAttachmentCandidate>[
          RunAttachmentCandidate(
            fileName: 'good.png',
            sizeBytes: 1024,
            bytes: pngBytes(1024),
          ),
          RunAttachmentCandidate(
            fileName: 'bad.pdf',
            sizeBytes: pdfBytes().length,
            bytes: pdfBytes(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('good.png · 1.0 KB'), findsOneWidget);
      expect(
        find.text('bad.pdf is not a PNG, JPEG, WebP or GIF image.'),
        findsOneWidget,
      );
    });

    testWidgets('submitting sends StartRunRequest with attachment payload', (
      tester,
    ) async {
      final ctx = await openAttachmentDialog(tester);
      final bytes = pngBytes(512);

      ctx.inputSource.emit(
        AttachmentFilesDropped(<RunAttachmentCandidate>[
          RunAttachmentCandidate(
            fileName: 'shot.png',
            sizeBytes: bytes.length,
            bytes: bytes,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('start_run_input_field')),
        'Check this screenshot',
      );
      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      final req = ctx.runsRepo.lastStartRequest;
      expect(req, isNotNull);
      expect(req!.input, 'Check this screenshot');
      expect(req.attachments, hasLength(1));
      expect(req.attachments!.first.fileName, 'shot.png');
      expect(req.attachments!.first.mimeType, 'image/png');
      expect(req.attachments!.first.data, base64Encode(bytes));
    });

    testWidgets('allows starting with attachments and empty text', (
      tester,
    ) async {
      final ctx = await openAttachmentDialog(tester);
      ctx.inputSource.clipboardImage = pngBytes(256);

      await pasteShortcut(tester);
      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      final req = ctx.runsRepo.lastStartRequest;
      expect(req, isNotNull);
      expect(req!.input, isNull);
      expect(req.attachments, hasLength(1));
    });

    testWidgets('Ctrl+V falls back to text paste when clipboard has no image', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, Object?>{'text': 'hello from clipboard'};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await openAttachmentDialog(tester);
      await pasteShortcut(tester);

      expect(find.byType(HiveRemovableChip), findsNothing);
      final field = tester.widget<HiveTextArea>(
        find.byKey(const Key('start_run_input_field')),
      );
      expect(field.controller?.text, 'hello from clipboard');
    });

    testWidgets(
      'hides chip remove button while submitting and keeps chips on failure',
      (tester) async {
        final completer = Completer<Result<Run>>();
        final slowRepo = _PendingStartRunRepository(completer.future);
        final ctx = await openAttachmentDialog(tester, runsRepo: slowRepo);

        ctx.inputSource.emit(
          AttachmentFilesDropped(<RunAttachmentCandidate>[
            RunAttachmentCandidate(
              fileName: 'keep.png',
              sizeBytes: 1024,
              bytes: pngBytes(1024),
            ),
          ]),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Remove keep.png'), findsOneWidget);

        await tester.tap(find.byKey(const Key('start_run_confirm_button')));
        await tester.pump();

        expect(find.text('keep.png · 1.0 KB'), findsOneWidget);
        expect(find.bySemanticsLabel('Remove keep.png'), findsNothing);

        completer.complete(const FailureResult(BackendFailure('Server error')));
        await tester.pumpAndSettle();

        expect(find.text('keep.png · 1.0 KB'), findsOneWidget);
        expect(find.bySemanticsLabel('Remove keep.png'), findsOneWidget);
        expect(find.byKey(const Key('start_run_error_banner')), findsOneWidget);
      },
    );
  });
}

final class _PendingStartRunRepository extends _FakeRunRepository {
  new(this._future);

  final Future<Result<Run>> _future;

  @override
  Future<Result<Run>> startRun(StartRunRequest request) {
    lastStartRequest = request;
    return _future;
  }
}
