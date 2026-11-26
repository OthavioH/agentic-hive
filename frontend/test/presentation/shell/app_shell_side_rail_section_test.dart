import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/core/shell/side_rail_pin_store.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:agentic_hive_frontend/data/skills/skill_notice_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_tree_changes_providers.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
import 'package:agentic_hive_frontend/presentation/shell/widgets/app_shell.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/side_rail_tree_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/side_rail_tree.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../harnesses/scripted_harness_repository.dart';
import '../skills/memory_outdated_banner_store.dart';
import '../skills/scripted_skill_notice_repository.dart';
import '../workspace/fake_workspace_repository.dart';

final class _FakePinStore implements SideRailPinStore {
  bool pinned = false;
  final List<bool> saved = <bool>[];

  @override
  Future<bool> load() async => pinned;

  @override
  Future<void> save(bool next) async {
    pinned = next;
    saved.add(next);
  }
}

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String? workspaceId) async {}
}

final class _NoChangesSource implements WorkspaceTreeChangesSource {
  @override
  Stream<WorkspaceTreeChange> get changes =>
      const Stream<WorkspaceTreeChange>.empty();
}

final class _FakeRunsRepo implements RunRepository {
  List<RunSummary> runs = <RunSummary>[];
  int listCalls = 0;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async {
    listCalls++;
    final filtered = workspaceId == null
        ? runs
        : runs.where((r) => r.workspaceId == workspaceId).toList();
    return Success<RunsListResponse>(
      RunsListResponse(items: filtered, total: filtered.length),
    );
  }

  @override
  Future<Result<Run>> cancelRun(String id) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteRun(String id) => throw UnimplementedError();

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> getRun(String id) => throw UnimplementedError();

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> resumeRun(String id) => throw UnimplementedError();

  @override
  Future<Result<Run>> startRun(StartRunRequest request) =>
      throw UnimplementedError();
}

final class _FakePauseRepo implements PauseRepository {
  @override
  Future<Result<List<Pause>>> listPendingPauses() async =>
      const Success<List<Pause>>(<Pause>[]);

  @override
  Future<Result<Pause>> answerPause(String id, AnswerPauseRequest request) =>
      throw UnimplementedError();

  @override
  Stream<PauseEvent> watchPauseEvents() => const Stream<PauseEvent>.empty();

  @override
  Stream<int> watchPendingPausesCount() => const Stream<int>.empty();
}

final class _FakeWorkflowRepo implements WorkflowRepository {
  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success<List<WorkflowSummary>>(<WorkflowSummary>[]);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) => throw UnimplementedError();

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) => throw UnimplementedError();

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  }) => throw UnimplementedError();

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) => throw UnimplementedError();

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) => throw UnimplementedError();

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) => throw UnimplementedError();
}

final class _FakeSettingsRepo implements SettingsRepository {
  @override
  Future<Result<AppSettings>> getSettings() async => const Success<AppSettings>(
    AppSettings(
      defaultAgentsDir: '/tmp/agents',
      effectiveAgentsDir: '/tmp/agents',
    ),
  );

  @override
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request) =>
      throw UnimplementedError();

  @override
  Stream<AppSettings> watchSettingsUpdates() =>
      const Stream<AppSettings>.empty();
}

RunSummary _makeRun({
  required String id,
  required String workspaceId,
  required String workflowName,
  required RunStatus status,
  required DateTime startedAt,
  DateTime? finishedAt,
  String? worktreePath,
}) => RunSummary(
  id: id,
  workflowName: workflowName,
  status: status,
  startedAt: startedAt,
  finishedAt: finishedAt,
  checkpointCount: 1,
  workspaceId: workspaceId,
  worktreePath: worktreePath,
);

Widget _mountShellApp({
  required FakeWorkspaceRepository workspaceRepo,
  required _FakeRunsRepo runsRepo,
  required _FakePinStore pinStore,
  required DateTime fixedNow,
  void Function(String path)? onRoute,
}) {
  final harnessRepo = ScriptedHarnessRepository();
  final noticeRepo = ScriptedSkillNoticeRepository();
  addTearDown(harnessRepo.dispose);
  addTearDown(noticeRepo.dispose);

  final container = ProviderContainer.test(
    overrides: [
      sideRailPinStoreProvider.overrideWithValue(pinStore),
      workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
      workspaceSelectionStoreProvider.overrideWithValue(_FakeSelectionStore()),
      runRepositoryProvider.overrideWithValue(runsRepo),
      pauseRepositoryProvider.overrideWithValue(_FakePauseRepo()),
      workflowRepositoryProvider.overrideWithValue(_FakeWorkflowRepo()),
      settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
      sideRailTreeClockProvider.overrideWithValue(() => fixedNow),
      workspaceTreeChangesSourceProvider.overrideWithValue(_NoChangesSource()),
      sideRailTreeDebounceProvider.overrideWithValue(Duration.zero),
      harnessRepositoryProvider.overrideWithValue(harnessRepo),
      skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
      outdatedBannerStoreProvider.overrideWithValue(
        MemoryOutdatedBannerStore(),
      ),
    ],
  );

  final router = GoRouter(
    initialLocation: '/overview',
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/overview',
            builder: (context, state) {
              onRoute?.call(state.uri.path);
              return const Center(child: Text('Overview Page'));
            },
          ),
          GoRoute(
            path: '/runs/:id',
            builder: (context, state) {
              onRoute?.call(state.uri.path);
              return Center(child: Text('Run ${state.pathParameters['id']}'));
            },
          ),
        ],
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: HiveTheme.dark(),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  const desktopSize = Size(1440, 900);
  final fixedNow = DateTime.utc(2026, 11, 25, 10);

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(HiveMotionTokens.standard.long);
    await tester.pump();
  }

  ({
    FakeWorkspaceRepository workspaceRepo,
    _FakeRunsRepo runsRepo,
    _FakePinStore pinStore,
  })
  buildPopulatedDeps({bool withActiveRuns = true}) {
    final ws1 = makeWorkspace(name: 'hive-core', rootPath: '/repos/hive-core');
    final ws2 = makeWorkspace(
      id: 'ws-2',
      name: 'hive-docs',
      rootPath: '/repos/hive-docs',
    );
    final wt1 = makeWorktree(
      id: 'wt-1',
      name: 'main',
      path: '/repos/hive-core',
    );
    final wt2 = makeWorktree(
      id: 'wt-2',
      name: 'feat-panel',
      path: '/repos/hive-core-wt',
      branch: 'feat/panel',
      isPrimary: false,
    );
    final wt3 = makeWorktree(
      id: 'wt-3',
      name: 'main',
      path: '/repos/hive-docs',
    );
    final workspaceRepo = FakeWorkspaceRepository(workspaces: [ws1, ws2])
      ..worktreesByWorkspaceId = {
        'ws-1': [wt1, wt2],
        'ws-2': [wt3],
      };

    final runsRepo = _FakeRunsRepo()
      ..runs = withActiveRuns
          ? <RunSummary>[
              _makeRun(
                id: 'run-1',
                workspaceId: 'ws-1',
                workflowName: 'CI Pipeline',
                status: RunStatus.running,
                startedAt: DateTime.utc(2026, 11, 25, 9, 59, 30),
                worktreePath: '/repos/hive-core',
              ),
              _makeRun(
                id: 'run-2',
                workspaceId: 'ws-1',
                workflowName: 'Deploy Staging',
                status: RunStatus.paused,
                startedAt: DateTime.utc(2026, 11, 25, 9, 58),
                worktreePath: '/repos/hive-core-wt',
              ),
              _makeRun(
                id: 'run-3',
                workspaceId: 'ws-2',
                workflowName: 'Build Docs',
                status: RunStatus.cancelling,
                startedAt: DateTime.utc(2026, 11, 25, 9, 59, 15),
                worktreePath: '/repos/hive-docs',
              ),
              _makeRun(
                id: 'run-4',
                workspaceId: 'ws-2',
                workflowName: 'Old Check',
                status: RunStatus.succeeded,
                startedAt: DateTime.utc(2026, 11, 25, 9),
                finishedAt: DateTime.utc(2026, 11, 25, 9, 5),
                worktreePath: '/repos/hive-docs',
              ),
            ]
          : <RunSummary>[];

    return (
      workspaceRepo: workspaceRepo,
      runsRepo: runsRepo,
      pinStore: _FakePinStore(),
    );
  }

  group('AppShell side-rail section', () {
    testWidgets(
      'shows Workspaces semantics without badge when zero active runs',
      (tester) async {
        await tester.binding.setSurfaceSize(desktopSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final deps = buildPopulatedDeps(withActiveRuns: false);
        await tester.pumpWidget(
          _mountShellApp(
            workspaceRepo: deps.workspaceRepo,
            runsRepo: deps.runsRepo,
            pinStore: deps.pinStore,
            fixedNow: fixedNow,
          ),
        );
        await pumpShell(tester);

        expect(find.bySemanticsLabel('Workspaces'), findsWidgets);
        expect(find.text('0'), findsNothing);
      },
    );

    testWidgets(
      'shows total active runs badge excluded from semantics and l10n label',
      (tester) async {
        await tester.binding.setSurfaceSize(desktopSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final deps = buildPopulatedDeps();
        await tester.pumpWidget(
          _mountShellApp(
            workspaceRepo: deps.workspaceRepo,
            runsRepo: deps.runsRepo,
            pinStore: deps.pinStore,
            fixedNow: fixedNow,
          ),
        );
        await pumpShell(tester);

        expect(
          find.bySemanticsLabel('Workspaces, 3 active runs'),
          findsOneWidget,
        );
        expect(find.text('3'), findsOneWidget);
        expect(find.bySemanticsLabel('3'), findsNothing);
      },
    );

    testWidgets('opening panel shows SideRailTree and refresh reloads tree', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final deps = buildPopulatedDeps();
      await tester.pumpWidget(
        _mountShellApp(
          workspaceRepo: deps.workspaceRepo,
          runsRepo: deps.runsRepo,
          pinStore: deps.pinStore,
          fixedNow: fixedNow,
        ),
      );
      await pumpShell(tester);

      await tester.tap(find.bySemanticsLabel('Workspaces, 3 active runs'));
      await pumpShell(tester);

      expect(find.byType(SideRailTree), findsOneWidget);
      expect(
        find.byKey(const Key('side_rail_tree_refresh_button')),
        findsOneWidget,
      );

      final beforeCalls = deps.runsRepo.listCalls;
      await tester.tap(find.byKey(const Key('side_rail_tree_refresh_button')));
      await pumpShell(tester);
      expect(deps.runsRepo.listCalls, greaterThan(beforeCalls));
    });

    testWidgets('clicking a run navigates and closes unpinned panel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final routes = <String>[];
      final deps = buildPopulatedDeps();
      await tester.pumpWidget(
        _mountShellApp(
          workspaceRepo: deps.workspaceRepo,
          runsRepo: deps.runsRepo,
          pinStore: deps.pinStore,
          fixedNow: fixedNow,
          onRoute: routes.add,
        ),
      );
      await pumpShell(tester);

      await tester.tap(find.bySemanticsLabel('Workspaces, 3 active runs'));
      await pumpShell(tester);
      expect(find.byType(SideRailTree), findsOneWidget);

      await tester.tap(find.byKey(const Key('tree_run_run-1')));
      await pumpShell(tester);

      expect(routes, contains('/runs/run-1'));
      expect(find.text('Run run-1'), findsOneWidget);
      expect(find.byType(SideRailTree), findsNothing);
    });

    testWidgets(
      'StartRunDialog and Remove worktree dialog keep unpinned panel open',
      (tester) async {
        await tester.binding.setSurfaceSize(desktopSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final deps = buildPopulatedDeps();
        await tester.pumpWidget(
          _mountShellApp(
            workspaceRepo: deps.workspaceRepo,
            runsRepo: deps.runsRepo,
            pinStore: deps.pinStore,
            fixedNow: fixedNow,
          ),
        );
        await pumpShell(tester);

        await tester.tap(find.bySemanticsLabel('Workspaces, 3 active runs'));
        await pumpShell(tester);
        expect(find.byType(SideRailTree), findsOneWidget);

        // Open StartRunDialog from tree.
        await tester.tap(find.byKey(const Key('tree_start_run_ws-1_wt-1')));
        await pumpShell(tester);
        expect(find.byType(StartRunDialog), findsOneWidget);
        expect(find.byType(SideRailTree), findsOneWidget);

        // Cancel StartRunDialog: panel remains open.
        await tester.tap(find.byKey(const Key('start_run_cancel_button')));
        await pumpShell(tester);
        expect(find.byType(StartRunDialog), findsNothing);
        expect(find.byType(SideRailTree), findsOneWidget);

        // Open Remove worktree dialog from tree.
        await tester.tap(
          find.byKey(const Key('tree_remove_worktree_ws-1_wt-2')),
        );
        await pumpShell(tester);
        expect(find.byType(HiveConfirmDialog), findsOneWidget);
        expect(find.byType(SideRailTree), findsOneWidget);

        // Cancel Remove worktree dialog: panel remains open.
        await tester.tap(find.text('Cancel'));
        await pumpShell(tester);
        expect(find.byType(HiveConfirmDialog), findsNothing);
        expect(find.byType(SideRailTree), findsOneWidget);
      },
    );

    testWidgets('pinning panel persists state and stays open on run click', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final deps = buildPopulatedDeps();
      await tester.pumpWidget(
        _mountShellApp(
          workspaceRepo: deps.workspaceRepo,
          runsRepo: deps.runsRepo,
          pinStore: deps.pinStore,
          fixedNow: fixedNow,
        ),
      );
      await pumpShell(tester);

      await tester.tap(find.bySemanticsLabel('Workspaces, 3 active runs'));
      await pumpShell(tester);

      await tester.tap(find.bySemanticsLabel('Pin panel'));
      await pumpShell(tester);

      expect(deps.pinStore.saved, <bool>[true]);
      expect(find.bySemanticsLabel('Unpin panel'), findsOneWidget);
      expect(find.byType(SideRailTree), findsOneWidget);

      // Clicking a run keeps the pinned panel open.
      await tester.tap(find.byKey(const Key('tree_run_run-1')));
      await pumpShell(tester);
      expect(find.text('Run run-1'), findsOneWidget);
      expect(find.byType(SideRailTree), findsOneWidget);
    });
  });
}
