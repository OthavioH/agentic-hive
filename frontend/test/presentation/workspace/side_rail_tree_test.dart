import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
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

import 'fake_workspace_repository.dart';

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  String? savedId;

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async {
    savedId = workspaceId;
  }
}

final class _FakeRunsRepo implements RunRepository {
  List<RunSummary> runs = <RunSummary>[];
  Failure? listFailure;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async {
    final failure = listFailure;
    if (failure != null) return FailureResult<RunsListResponse>(failure);
    return Success<RunsListResponse>(
      RunsListResponse(items: runs, total: runs.length),
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
  List<Pause> pauses = <Pause>[];

  @override
  Future<Result<List<Pause>>> listPendingPauses() async =>
      Success<List<Pause>>(pauses);

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
  Future<Result<List<WorkflowSummary>>> listWorkflows() async =>
      const Success<List<WorkflowSummary>>(<WorkflowSummary>[]);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteWorkflow(String id) => throw UnimplementedError();

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
  }) => throw UnimplementedError();

  @override
  Future<Result<WorkflowResponse>> getWorkflow(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request,
  ) => throw UnimplementedError();

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

Widget _buildRouterApp({
  required FakeWorkspaceRepository workspaceRepo,
  required _FakeSelectionStore selectionStore,
  required _FakeRunsRepo runsRepo,
  required _FakePauseRepo pauseRepo,
  required DateTime fixedNow,
  void Function(String path)? onRoute,
  double textScale = 1.0,
}) {
  final container = ProviderContainer.test(
    overrides: [
      workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
      workspaceSelectionStoreProvider.overrideWithValue(selectionStore),
      runRepositoryProvider.overrideWithValue(runsRepo),
      pauseRepositoryProvider.overrideWithValue(pauseRepo),
      workflowRepositoryProvider.overrideWithValue(_FakeWorkflowRepo()),
      settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
      sideRailTreeClockProvider.overrideWithValue(() => fixedNow),
    ],
  );
  final router = GoRouter(
    initialLocation: '/overview',
    routes: <RouteBase>[
      GoRoute(
        path: '/overview',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) {
              final spacing = context.hiveSpacing;
              return SizedBox(
                width: spacing.space8 * 5 + spacing.space2,
                child: SideRailTree(currentLocation: state.uri.path),
              );
            },
          ),
        ),
      ),
      GoRoute(
        path: '/runs/:id',
        builder: (context, state) {
          onRoute?.call(state.uri.path);
          return Scaffold(body: Text('Run ${state.pathParameters['id']}'));
        },
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
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
    ),
  );
}

void main() {
  final fixedNow = DateTime.utc(2026, 11, 22, 12);

  late FakeWorkspaceRepository workspaceRepo;
  late _FakeSelectionStore selectionStore;
  late _FakeRunsRepo runsRepo;
  late _FakePauseRepo pauseRepo;

  setUp(() {
    workspaceRepo = FakeWorkspaceRepository();
    selectionStore = _FakeSelectionStore();
    runsRepo = _FakeRunsRepo();
    pauseRepo = _FakePauseRepo();
  });

  testWidgets('renders empty state when no workspaces are registered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildRouterApp(
        workspaceRepo: workspaceRepo,
        selectionStore: selectionStore,
        runsRepo: runsRepo,
        pauseRepo: pauseRepo,
        fixedNow: fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No workspaces yet'), findsOneWidget);
  });

  testWidgets('renders error state and retries on tap', (tester) async {
    workspaceRepo.listWorkspacesFailure = const NetworkFailure('offline');

    await tester.pumpWidget(
      _buildRouterApp(
        workspaceRepo: workspaceRepo,
        selectionStore: selectionStore,
        runsRepo: runsRepo,
        pauseRepo: pauseRepo,
        fixedNow: fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load workspace tree'), findsOneWidget);

    workspaceRepo
      ..listWorkspacesFailure = null
      ..workspaces = <Workspace>[makeWorkspace(name: 'Alpha', isGit: false)];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('renders tree hierarchy, badges, 3-run cap with see all, '
      'pause highlight, navigation, and Start Run preselection', (
    tester,
  ) async {
    final ws1 = makeWorkspace(
      name: 'Agentic Hive',
      rootPath: '/repos/hive',
      activeRunCount: 1,
    );
    final ws2 = makeWorkspace(
      id: 'ws-2',
      name: 'Notes',
      rootPath: '/docs/notes',
      isGit: false,
    );
    workspaceRepo.workspaces = <Workspace>[ws1, ws2];
    workspaceRepo.worktreesByWorkspaceId['ws-1'] = <Worktree>[
      makeWorktree(path: '/repos/hive'),
      makeWorktree(
        id: 'feat-ui',
        name: 'feat-ui',
        path: '/data/worktrees/ws-1/feat-ui',
        isPrimary: false,
        branch: 'feature/ui',
        hasUncommittedChanges: true,
      ),
    ];
    runsRepo.runs = <RunSummary>[
      _makeRun(
        id: 'run-paused',
        workspaceId: 'ws-1',
        workflowName: 'Paused Flow',
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 22, 11, 56),
        worktreePath: '/repos/hive',
      ),
      for (var i = 0; i < 4; i++)
        _makeRun(
          id: 'run-recent-$i',
          workspaceId: 'ws-1',
          workflowName: 'Recent $i',
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 11, 22, 11 - i),
          finishedAt: DateTime.utc(2026, 11, 22, 11, 50 - i * 10),
          worktreePath: '/repos/hive',
        ),
    ];
    pauseRepo.pauses = <Pause>[
      Pause(
        id: 'p-1',
        runId: 'run-paused',
        nodeId: 'n-1',
        kind: PauseKind.humanApproval,
        workflowName: 'Paused Flow',
        nodeLabel: 'Approve',
        status: PauseStatus.pending,
        createdAt: fixedNow,
      ),
    ];

    String? navigatedTo;
    await tester.pumpWidget(
      _buildRouterApp(
        workspaceRepo: workspaceRepo,
        selectionStore: selectionStore,
        runsRepo: runsRepo,
        pauseRepo: pauseRepo,
        fixedNow: fixedNow,
        onRoute: (path) => navigatedTo = path,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agentic Hive'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('tree_worktree_ws-1_primary')),
        matching: find.text('primary'),
      ),
      findsNWidgets(2),
    );
    expect(find.text('main'), findsOneWidget);
    expect(find.text('feat-ui'), findsOneWidget);
    expect(find.text('feature/ui'), findsOneWidget);
    expect(
      find.byKey(const Key('tree_worktree_dirty_ws-1_feat-ui')),
      findsOneWidget,
    );
    expect(find.text('Paused Flow'), findsOneWidget);

    // 4 recent runs -> 3 visible + "See all (1 more)"
    expect(find.text('Recent 0'), findsOneWidget);
    expect(find.text('Recent 3'), findsNothing);
    expect(find.text('See all (1 more)'), findsOneWidget);

    await tester.tap(find.text('See all (1 more)'));
    await tester.pumpAndSettle();
    expect(find.text('Recent 3'), findsOneWidget);

    // Clicking Start Run on feat-ui opens StartRunDialog with its workspace
    // preselected.
    await tester.tap(find.byKey(const Key('tree_start_run_ws-1_feat-ui')));
    await tester.pumpAndSettle();
    expect(find.byType(StartRunDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('start_run_workspace_select')),
        matching: find.text('Agentic Hive'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('start_run_cancel_button')));
    await tester.pumpAndSettle();

    // Clicking workspace Notes selects it
    await tester.tap(find.byKey(const Key('tree_workspace_ws-2')));
    await tester.pumpAndSettle();
    expect(selectionStore.savedId, 'ws-2');

    // Clicking run opens /runs/:id
    await tester.tap(find.text('Paused Flow'));
    await tester.pumpAndSettle();
    expect(navigatedTo, '/runs/run-paused');
  });

  testWidgets('wraps cleanly at large text scale without overflow', (
    tester,
  ) async {
    workspaceRepo.workspaces = <Workspace>[
      makeWorkspace(name: 'Large Text Workspace'),
    ];
    workspaceRepo.worktreesByWorkspaceId['ws-1'] = <Worktree>[
      makeWorktree(path: '/repos/hive', branch: 'main-long-branch-name'),
    ];
    runsRepo.runs = <RunSummary>[
      _makeRun(
        id: 'run-1',
        workspaceId: 'ws-1',
        workflowName: 'Long Workflow Execution Name',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 22, 11, 58),
      ),
    ];

    await tester.pumpWidget(
      _buildRouterApp(
        workspaceRepo: workspaceRepo,
        selectionStore: selectionStore,
        runsRepo: runsRepo,
        pauseRepo: pauseRepo,
        fixedNow: fixedNow,
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Large Text Workspace'), findsOneWidget);
  });
}
