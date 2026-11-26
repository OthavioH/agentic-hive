import 'dart:async';

import 'package:agentic_hive_frontend/core/attachments/attachment_input_source.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
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
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
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

import '../../support/fake_attachment_input_source.dart';
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

  /// When set, `listRuns` waits for it, keeping a reload in flight.
  Completer<void>? listGate;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async {
    await listGate?.future;
    final failure = listFailure;
    if (failure != null) return FailureResult<RunsListResponse>(failure);
    final filtered = status == null
        ? runs
        : runs.where((r) => r.status == status).toList();
    final start = offset ?? 0;
    final page = limit == null
        ? filtered.skip(start).toList()
        : filtered.skip(start).take(limit).toList();
    return Success<RunsListResponse>(
      RunsListResponse(items: page, total: filtered.length),
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

final class _FakeChangesSource implements WorkspaceTreeChangesSource {
  final StreamController<WorkspaceTreeChange> controller =
      StreamController<WorkspaceTreeChange>.broadcast();

  @override
  Stream<WorkspaceTreeChange> get changes => controller.stream;

  void emit(WorkspaceTreeChange change) => controller.add(change);
}

Pause _pendingPause(String runId, DateTime createdAt) => Pause(
  id: 'pause-$runId',
  runId: runId,
  nodeId: 'n-1',
  kind: PauseKind.humanApproval,
  workflowName: 'Flow',
  nodeLabel: 'Approve',
  status: PauseStatus.pending,
  createdAt: createdAt,
);

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
  required _FakeChangesSource changes,
  DateTime Function()? clock,
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
      sideRailTreeClockProvider.overrideWithValue(clock ?? () => fixedNow),
      workspaceTreeChangesSourceProvider.overrideWithValue(changes),
      sideRailTreeDebounceProvider.overrideWithValue(Duration.zero),
      attachmentInputSourceProvider.overrideWithValue(
        FakeAttachmentInputSource(),
      ),
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

const int oneSecond = 1;
const int fiveSeconds = 5;

void main() {
  final fixedNow = DateTime.utc(2026, 11, 22, 12);

  late FakeWorkspaceRepository workspaceRepo;
  late _FakeSelectionStore selectionStore;
  late _FakeRunsRepo runsRepo;
  late _FakePauseRepo pauseRepo;
  late _FakeChangesSource changes;

  setUp(() {
    workspaceRepo = FakeWorkspaceRepository();
    selectionStore = _FakeSelectionStore();
    runsRepo = _FakeRunsRepo();
    pauseRepo = _FakePauseRepo();
    changes = _FakeChangesSource();
    addTearDown(changes.controller.close);
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
        changes: changes,
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
        changes: changes,
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
        changes: changes,
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
    await tester.ensureVisible(find.byKey(const Key('tree_workspace_ws-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tree_workspace_ws-2')));
    await tester.pumpAndSettle();
    expect(selectionStore.savedId, 'ws-2');

    // Clicking run opens /runs/:id
    await tester.ensureVisible(find.text('Paused Flow'));
    await tester.pumpAndSettle();
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
        changes: changes,
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Large Text Workspace'), findsOneWidget);
  });

  group('captured gallery states', () {
    testWidgets('a non-git workspace shows only its primary folder, with no '
        'branch, badge or dirty indicator', (tester) async {
      workspaceRepo
        ..workspaces = <Workspace>[
          makeWorkspace(
            id: 'ws-docs',
            name: 'Docs',
            rootPath: '/docs/notes',
            isGit: false,
          ),
        ]
        ..worktreesByWorkspaceId['ws-docs'] = <Worktree>[];
      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-docs',
          workspaceId: 'ws-docs',
          workflowName: 'Summarize',
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 11, 22, 11, 30),
          finishedAt: DateTime.utc(2026, 11, 22, 11, 40),
        ),
      ];

      await tester.pumpWidget(
        _buildRouterApp(
          workspaceRepo: workspaceRepo,
          selectionStore: selectionStore,
          runsRepo: runsRepo,
          pauseRepo: pauseRepo,
          fixedNow: fixedNow,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Docs'), findsOneWidget);
      expect(
        find.byKey(const Key('tree_worktree_ws-docs_primary')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('tree_start_run_ws-docs_primary')), findsOne);
      expect(find.byType(HiveBadge), findsNothing);
      expect(
        find.byKey(const Key('tree_worktree_dirty_ws-docs_primary')),
        findsNothing,
      );
      expect(find.text('Summarize'), findsOneWidget);
    });

    testWidgets('a run with a pending pause is highlighted, with its '
        'workspace, and other runs are not', (tester) async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace(activeRunCount: 2)]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-paused',
          workspaceId: 'ws-1',
          workflowName: 'Review',
          status: RunStatus.paused,
          startedAt: DateTime.utc(2026, 11, 22, 11, 50),
          worktreePath: '/tmp/ws-1',
        ),
        _makeRun(
          id: 'run-busy',
          workspaceId: 'ws-1',
          workflowName: 'Build',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 22, 11, 55),
          worktreePath: '/tmp/ws-1',
        ),
      ];
      pauseRepo.pauses = <Pause>[_pendingPause('run-paused', fixedNow)];

      await tester.pumpWidget(
        _buildRouterApp(
          workspaceRepo: workspaceRepo,
          selectionStore: selectionStore,
          runsRepo: runsRepo,
          pauseRepo: pauseRepo,
          fixedNow: fixedNow,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();

      HiveTreeItem item(String key) =>
          tester.widget<HiveTreeItem>(find.byKey(Key(key)));
      expect(item('tree_run_run-paused').highlighted, isTrue);
      expect(item('tree_run_run-busy').highlighted, isFalse);
      expect(item('tree_workspace_ws-1').highlighted, isTrue);
    });
  });

  group('live updates', () {
    testWidgets('a pause created while the tree is open highlights its run '
        'without a refresh', (tester) async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace(activeRunCount: 1)]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-1',
          workspaceId: 'ws-1',
          workflowName: 'Review',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 22, 11, 50),
          worktreePath: '/tmp/ws-1',
        ),
      ];
      await tester.pumpWidget(
        _buildRouterApp(
          workspaceRepo: workspaceRepo,
          selectionStore: selectionStore,
          runsRepo: runsRepo,
          pauseRepo: pauseRepo,
          fixedNow: fixedNow,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<HiveTreeItem>(find.byKey(const Key('tree_run_run-1')))
            .highlighted,
        isFalse,
      );

      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-1',
          workspaceId: 'ws-1',
          workflowName: 'Review',
          status: RunStatus.paused,
          startedAt: DateTime.utc(2026, 11, 22, 11, 50),
          worktreePath: '/tmp/ws-1',
        ),
      ];
      pauseRepo.pauses = <Pause>[_pendingPause('run-1', fixedNow)];
      changes.emit(WorkspaceTreeChange.pause);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<HiveTreeItem>(find.byKey(const Key('tree_run_run-1')))
            .highlighted,
        isTrue,
      );
      expect(
        tester
            .widget<HiveStatusDot>(
              find.descendant(
                of: find.byKey(const Key('tree_run_run-1')),
                matching: find.byType(HiveStatusDot),
              ),
            )
            .status,
        RunL10n.nodeStatusFor(RunStatus.paused),
      );
    });

    testWidgets('a run started while the tree is open appears and a worktree '
        'created appears', (tester) async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace()]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      await tester.pumpWidget(
        _buildRouterApp(
          workspaceRepo: workspaceRepo,
          selectionStore: selectionStore,
          runsRepo: runsRepo,
          pauseRepo: pauseRepo,
          fixedNow: fixedNow,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh run'), findsNothing);

      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-new',
          workspaceId: 'ws-1',
          workflowName: 'Fresh run',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 22, 11, 59),
          worktreePath: '/tmp/ws-1',
        ),
      ];
      workspaceRepo.worktreesByWorkspaceId['ws-1'] = <Worktree>[
        makeWorktree(),
        makeWorktree(
          id: 'feat-live',
          name: 'feat-live',
          path: '/data/worktrees/ws-1/feat-live',
          isPrimary: false,
          branch: 'feature/live',
        ),
      ];
      changes
        ..emit(WorkspaceTreeChange.run)
        ..emit(WorkspaceTreeChange.worktree);
      await tester.pumpAndSettle();

      expect(find.text('Fresh run'), findsOneWidget);
      expect(find.text('feat-live'), findsOneWidget);
    });

    testWidgets('elapsed time of an active run keeps counting', (tester) async {
      var now = DateTime.utc(2026, 11, 22, 12);
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace(activeRunCount: 1)]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-1',
          workspaceId: 'ws-1',
          workflowName: 'Build',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 22, 11, 56),
          worktreePath: '/tmp/ws-1',
        ),
      ];
      await tester.pumpWidget(
        _buildRouterApp(
          workspaceRepo: workspaceRepo,
          selectionStore: selectionStore,
          runsRepo: runsRepo,
          pauseRepo: pauseRepo,
          fixedNow: fixedNow,
          clock: () => now,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4m 0s'), findsOneWidget);

      now = now.add(const Duration(seconds: fiveSeconds));
      await tester.pump(const Duration(seconds: oneSecond));
      await tester.pump();

      expect(find.text('4m 5s'), findsOneWidget);
      expect(find.text('4m 0s'), findsNothing);
    });

    testWidgets('a live reload keeps the tree on screen instead of '
        'flashing the loading spinner', (tester) async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace(name: 'Stable')]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      await tester.pumpWidget(
        _buildRouterApp(
          workspaceRepo: workspaceRepo,
          selectionStore: selectionStore,
          runsRepo: runsRepo,
          pauseRepo: pauseRepo,
          fixedNow: fixedNow,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();

      final gate = Completer<void>();
      runsRepo.listGate = gate;
      workspaceRepo.workspaces = <Workspace>[makeWorkspace(name: 'Renamed')];
      changes.emit(WorkspaceTreeChange.workspace);
      await tester.pump();
      await tester.pump();

      expect(find.byType(HiveSpinner), findsNothing);
      expect(find.byKey(const Key('tree_workspace_ws-1')), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Renamed'), findsOneWidget);
    });
  });

  group('remove worktree', () {
    testWidgets('non-primary worktree shows remove button, primary does not, '
        'and confirms before removing and showing unmerged notice', (
      tester,
    ) async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace()]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[
          makeWorktree(),
          makeWorktree(
            id: 'feat-ui',
            name: 'feat-ui',
            path: '/data/worktrees/ws-1/feat-ui',
            isPrimary: false,
            branch: 'feature/ui',
          ),
        ]
        ..removeWorktreeResult = const Success<RemoveWorktreeResponse>(
          RemoveWorktreeResponse(
            id: 'feat-ui',
            deleted: true,
            branchDeleted: false,
            notice: 'Branch feature/ui is not merged and was kept.',
          ),
        );

      await tester.pumpWidget(
        _buildRouterApp(
          workspaceRepo: workspaceRepo,
          selectionStore: selectionStore,
          runsRepo: runsRepo,
          pauseRepo: pauseRepo,
          fixedNow: fixedNow,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tree_remove_worktree_ws-1_primary')),
        findsNothing,
      );
      final removeButton = find.byKey(
        const Key('tree_remove_worktree_ws-1_feat-ui'),
      );
      expect(removeButton, findsOneWidget);

      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      expect(find.text('Remove worktree?'), findsOneWidget);
      expect(workspaceRepo.removeWorktreeCalls, isEmpty);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(
        workspaceRepo.removeWorktreeCalls,
        <({String workspaceId, String worktreeId, bool force})>[
          (workspaceId: 'ws-1', worktreeId: 'feat-ui', force: false),
        ],
      );
      expect(
        find.text('Branch feature/ui is not merged and was kept.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'dirty worktree 409 offers second confirmation and retries with force',
      (tester) async {
        var callCount = 0;
        workspaceRepo
          ..workspaces = <Workspace>[makeWorkspace()]
          ..worktreesByWorkspaceId['ws-1'] = <Worktree>[
            makeWorktree(),
            makeWorktree(
              id: 'feat-dirty',
              name: 'feat-dirty',
              path: '/data/worktrees/ws-1/feat-dirty',
              isPrimary: false,
              hasUncommittedChanges: true,
              branch: 'feature/dirty',
            ),
          ]
          ..onRemoveWorktree = (wsId, wtId, {required force}) {
            callCount++;
            if (callCount == 1 && !force) {
              return const FailureResult<RemoveWorktreeResponse>(
                BackendFailure(
                  'Worktree has uncommitted changes.',
                  statusCode: 409,
                ),
              );
            }
            return const Success<RemoveWorktreeResponse>(
              RemoveWorktreeResponse(
                id: 'feat-dirty',
                deleted: true,
                branchDeleted: true,
              ),
            );
          };

        await tester.pumpWidget(
          _buildRouterApp(
            workspaceRepo: workspaceRepo,
            selectionStore: selectionStore,
            runsRepo: runsRepo,
            pauseRepo: pauseRepo,
            fixedNow: fixedNow,
            changes: changes,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('tree_remove_worktree_ws-1_feat-dirty')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        // Explicit second confirmation for uncommitted changes.
        expect(find.text('Worktree has uncommitted changes'), findsOneWidget);
        await tester.tap(find.text('Discard & remove'));
        await tester.pumpAndSettle();

        expect(
          workspaceRepo.removeWorktreeCalls,
          <({String workspaceId, String worktreeId, bool force})>[
            (workspaceId: 'ws-1', worktreeId: 'feat-dirty', force: false),
            (workspaceId: 'ws-1', worktreeId: 'feat-dirty', force: true),
          ],
        );
      },
    );

    testWidgets('active run 409 shows error and does not offer force remove', (
      tester,
    ) async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace()]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[
          makeWorktree(),
          makeWorktree(
            id: 'feat-busy',
            name: 'feat-busy',
            path: '/data/worktrees/ws-1/feat-busy',
            isPrimary: false,
            branch: 'feature/busy',
          ),
        ]
        ..removeWorktreeResult = const FailureResult<RemoveWorktreeResponse>(
          BackendFailure('A run is active in worktree.', statusCode: 409),
        );

      await tester.pumpWidget(
        _buildRouterApp(
          workspaceRepo: workspaceRepo,
          selectionStore: selectionStore,
          runsRepo: runsRepo,
          pauseRepo: pauseRepo,
          fixedNow: fixedNow,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('tree_remove_worktree_ws-1_feat-busy')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Worktree has uncommitted changes'), findsNothing);
      expect(find.text('A run is active in worktree.'), findsOneWidget);
    });
  });

  group('Global entry', () {
    testWidgets(
      'tapping Global entry selects Global and deselects workspaces',
      (tester) async {
        workspaceRepo
          ..workspaces = <Workspace>[makeWorkspace()]
          ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];

        await tester.pumpWidget(
          _buildRouterApp(
            workspaceRepo: workspaceRepo,
            selectionStore: selectionStore,
            runsRepo: runsRepo,
            pauseRepo: pauseRepo,
            fixedNow: fixedNow,
            changes: changes,
          ),
        );
        await tester.pumpAndSettle();

        final globalFinder = find.byKey(const Key('tree_global_entry'));
        expect(globalFinder, findsOneWidget);
        expect(tester.widget<HiveTreeItem>(globalFinder).selected, isFalse);
        expect(
          tester
              .widget<HiveTreeItem>(
                find.byKey(const Key('tree_workspace_ws-1')),
              )
              .selected,
          isTrue,
        );

        await tester.tap(globalFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<HiveTreeItem>(globalFinder).selected, isTrue);
        expect(
          tester
              .widget<HiveTreeItem>(
                find.byKey(const Key('tree_workspace_ws-1')),
              )
              .selected,
          isFalse,
        );
      },
    );
  });

  group('missing worktree fallback group', () {
    testWidgets(
      'renders orphan runs in Removed worktrees group without start/remove '
      'buttons',
      (tester) async {
        workspaceRepo
          ..workspaces = <Workspace>[makeWorkspace()]
          ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
        runsRepo.runs = <RunSummary>[
          _makeRun(
            id: 'run-orphan',
            workspaceId: 'ws-1',
            workflowName: 'Orphan Workflow',
            status: RunStatus.running,
            startedAt: DateTime.utc(2026, 11, 22, 11, 57),
            worktreePath: '/data/worktrees/ws-1/gone',
          ),
        ];

        await tester.pumpWidget(
          _buildRouterApp(
            workspaceRepo: workspaceRepo,
            selectionStore: selectionStore,
            runsRepo: runsRepo,
            pauseRepo: pauseRepo,
            fixedNow: fixedNow,
            changes: changes,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Removed worktrees'), findsOneWidget);
        expect(find.text('Orphan Workflow'), findsOneWidget);
        expect(
          find.byKey(
            const Key(
              'tree_start_run_ws-1_'
              '${SideRailTreeController.missingWorktreesGroupId}',
            ),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key(
              'tree_remove_worktree_ws-1_'
              '${SideRailTreeController.missingWorktreesGroupId}',
            ),
          ),
          findsNothing,
        );
      },
    );
  });
}
