import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_tree_changes_providers.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/shell/widgets/app_shell.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/side_rail_tree_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/side_rail_tree.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

final class _NoChangesSource implements WorkspaceTreeChangesSource {
  @override
  Stream<WorkspaceTreeChange> get changes =>
      const Stream<WorkspaceTreeChange>.empty();
}

final class _FakeRunsRepo implements RunRepository {
  List<RunSummary> runs = <RunSummary>[];

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async => Success<RunsListResponse>(
    RunsListResponse(items: runs, total: runs.length),
  );

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

Future<void> _loadFonts() async {
  const fonts = <String, String>{
    'BricolageGrotesque':
        'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
    'Geist': 'assets/fonts/geist/Geist-Variable.ttf',
    'GeistMono': 'assets/fonts/geist_mono/GeistMono-Variable.ttf',
  };
  for (final entry in fonts.entries) {
    final candidates = <String>[
      'design_system/${entry.value}',
      '../design_system/${entry.value}',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      final loader = FontLoader('packages/design_system/${entry.key}')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      break;
    }
  }
}

String _galleryPath(String name) {
  final inFrontend = Directory('test/presentation/workspace').existsSync();
  final dir = inFrontend
      ? 'test/presentation/workspace/gallery_styled'
      : 'frontend/test/presentation/workspace/gallery_styled';
  Directory(dir).createSync(recursive: true);
  return '$dir/$name.png';
}

Future<void> _capture(
  WidgetTester tester, {
  required String name,
  required Size size,
  required ThemeData theme,
  required Widget child,
  required FakeWorkspaceRepository workspaceRepo,
  required _FakeSelectionStore selectionStore,
  required _FakeRunsRepo runsRepo,
  required _FakePauseRepo pauseRepo,
  required DateTime fixedNow,
  double textScale = 1.0,
  bool settle = true,
  bool checkContrast = false,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Future<void> Function()? afterCapture,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final boundaryKey = GlobalKey();
  final container = ProviderContainer.test(
    overrides: [
      workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
      workspaceSelectionStoreProvider.overrideWithValue(selectionStore),
      runRepositoryProvider.overrideWithValue(runsRepo),
      pauseRepositoryProvider.overrideWithValue(pauseRepo),
      sideRailTreeClockProvider.overrideWithValue(() => fixedNow),
      workspaceTreeChangesSourceProvider.overrideWithValue(_NoChangesSource()),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          key: ValueKey<String>(name),
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeAnimationDuration: Duration.zero,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(HiveMotionTokens.standard.medium);
  }

  if (beforeCapture != null) {
    await beforeCapture(tester);
  }

  if (checkContrast) {
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  }

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    File(_galleryPath(name)).writeAsBytesSync(bytes);
  });

  if (afterCapture != null) {
    await afterCapture();
  }
}

void main() {
  final fixedNow = DateTime.utc(2026, 11, 22, 12);

  setUpAll(_loadFonts);

  testWidgets('captures styled side rail tree gallery in dark and light', (
    tester,
  ) async {
    final emptyWsRepo = FakeWorkspaceRepository();
    final emptyRunsRepo = _FakeRunsRepo();
    final emptyPauseRepo = _FakePauseRepo();
    final selectionStore = _FakeSelectionStore();

    final themes = <String, ThemeData>{
      'dark': HiveTheme.dark(),
      'light': HiveTheme.light(),
    };

    var index = 1;
    String nextName(String slug) =>
        '${(index++).toString().padLeft(2, '0')}_$slug';

    // 01-02: Empty state (dark & light)
    for (final entry in themes.entries) {
      await _capture(
        tester,
        name: nextName('empty_${entry.key}'),
        size: const Size(360, 560),
        theme: entry.value,
        child: const SideRailTree(currentLocation: '/overview'),
        workspaceRepo: emptyWsRepo,
        selectionStore: selectionStore,
        runsRepo: emptyRunsRepo,
        pauseRepo: emptyPauseRepo,
        fixedNow: fixedNow,
        checkContrast: true,
      );
    }

    // 03-04: Loading state (dark & light)
    for (final entry in themes.entries) {
      final loadingWsRepo = FakeWorkspaceRepository()
        ..listWorkspacesGate = Completer<void>();
      await _capture(
        tester,
        name: nextName('loading_${entry.key}'),
        size: const Size(360, 560),
        theme: entry.value,
        child: const SideRailTree(currentLocation: '/overview'),
        workspaceRepo: loadingWsRepo,
        selectionStore: selectionStore,
        runsRepo: emptyRunsRepo,
        pauseRepo: emptyPauseRepo,
        fixedNow: fixedNow,
        settle: false,
      );
      loadingWsRepo.listWorkspacesGate!.complete();
    }

    // 05-06: Error state (dark & light)
    final errorWsRepo = FakeWorkspaceRepository()
      ..listWorkspacesFailure = const NetworkFailure('offline');
    for (final entry in themes.entries) {
      await _capture(
        tester,
        name: nextName('error_${entry.key}'),
        size: const Size(360, 560),
        theme: entry.value,
        child: const SideRailTree(currentLocation: '/overview'),
        workspaceRepo: errorWsRepo,
        selectionStore: selectionStore,
        runsRepo: emptyRunsRepo,
        pauseRepo: emptyPauseRepo,
        fixedNow: fixedNow,
      );
    }

    // Populated fixtures:
    // - ws-1: Git workspace, expanded, primary + feat-ui (dirty=true),
    //   running + cancelling + paused (pending pause) + 4 recent runs
    // - ws-2: Non-git workspace, expanded, primary only, no runs
    // - ws-3: Git workspace, collapsed, activeRunCount=1
    final populatedWsRepo = FakeWorkspaceRepository()
      ..workspaces = <Workspace>[
        makeWorkspace(
          name: 'Agentic Hive',
          rootPath: '/repos/hive',
          activeRunCount: 3,
        ),
        makeWorkspace(
          id: 'ws-2',
          name: 'Docs',
          rootPath: '/docs/notes',
          isGit: false,
        ),
        makeWorkspace(
          id: 'ws-3',
          name: 'Backend API',
          rootPath: '/repos/api',
          activeRunCount: 1,
        ),
      ]
      ..worktreesByWorkspaceId['ws-1'] = <Worktree>[
        makeWorktree(path: '/repos/hive'),
        makeWorktree(
          id: 'feat-ui',
          name: 'feat-ui',
          path: '/data/worktrees/ws-1/feat-ui',
          isPrimary: false,
          branch: 'feature/side-rail-tree',
          hasUncommittedChanges: true,
        ),
      ]
      ..worktreesByWorkspaceId['ws-3'] = <Worktree>[
        makeWorktree(path: '/repos/api'),
      ];

    final populatedRunsRepo = _FakeRunsRepo()
      ..runs = <RunSummary>[
        RunSummary(
          id: 'run-active-1',
          workflowName: 'Implement Tree',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 22, 11, 54),
          checkpointCount: 2,
          workspaceId: 'ws-1',
          worktreePath: '/repos/hive',
        ),
        RunSummary(
          id: 'run-cancelling-1',
          workflowName: 'Lint & Verify',
          status: RunStatus.cancelling,
          startedAt: DateTime.utc(2026, 11, 22, 11, 51),
          checkpointCount: 1,
          workspaceId: 'ws-1',
          worktreePath: '/repos/hive',
        ),
        RunSummary(
          id: 'run-paused-1',
          workflowName: 'Review & Approve',
          status: RunStatus.paused,
          startedAt: DateTime.utc(2026, 11, 22, 11, 45),
          checkpointCount: 3,
          workspaceId: 'ws-1',
          worktreePath: '/data/worktrees/ws-1/feat-ui',
          isolationMode: WorkspaceIsolationMode.worktree,
        ),
        for (var i = 0; i < 4; i++)
          RunSummary(
            id: 'run-recent-$i',
            workflowName: 'CI Check #$i',
            status: i == 1 ? RunStatus.failed : RunStatus.succeeded,
            startedAt: DateTime.utc(2026, 11, 22, 11 - i),
            finishedAt: DateTime.utc(2026, 11, 22, 11, 40 - i),
            checkpointCount: 1,
            workspaceId: 'ws-1',
            worktreePath: '/repos/hive',
          ),
        RunSummary(
          id: 'run-ws3-1',
          workflowName: 'Deploy Staging',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 22, 11, 58),
          checkpointCount: 1,
          workspaceId: 'ws-3',
          worktreePath: '/repos/api',
        ),
      ];
    final populatedPauseRepo = _FakePauseRepo()
      ..pauses = <Pause>[
        Pause(
          id: 'p-1',
          runId: 'run-paused-1',
          nodeId: 'n-approve',
          kind: PauseKind.humanApproval,
          workflowName: 'Review & Approve',
          nodeLabel: 'Approve',
          status: PauseStatus.pending,
          createdAt: DateTime.utc(2026, 11, 22, 11, 57),
        ),
      ];

    Future<void> collapseWs3(WidgetTester t) async {
      final finder = find.bySemanticsLabel('Collapse Backend API');
      await t.ensureVisible(finder);
      await t.tap(finder);
      await t.pump();
      await t.pump(HiveMotionTokens.standard.medium);
    }

    // 07-08: Populated state (dark & light)
    for (final entry in themes.entries) {
      await _capture(
        tester,
        name: nextName('populated_${entry.key}'),
        size: const Size(360, 820),
        theme: entry.value,
        child: const SideRailTree(currentLocation: '/runs/run-active-1'),
        workspaceRepo: populatedWsRepo,
        selectionStore: selectionStore,
        runsRepo: populatedRunsRepo,
        pauseRepo: populatedPauseRepo,
        fixedNow: fixedNow,
        settle: false,
        beforeCapture: collapseWs3,
        checkContrast: true,
      );
    }

    // 09-10: Interaction states (hover, focus, selected; dark & light)
    for (final entry in themes.entries) {
      TestGesture? hoverGesture;
      await _capture(
        tester,
        name: nextName('interaction_states_${entry.key}'),
        size: const Size(360, 560),
        theme: entry.value,
        child: const SideRailTree(currentLocation: '/runs/run-active-1'),
        workspaceRepo: populatedWsRepo,
        selectionStore: selectionStore,
        runsRepo: populatedRunsRepo,
        pauseRepo: populatedPauseRepo,
        fixedNow: fixedNow,
        settle: false,
        beforeCapture: (t) async {
          // Focus the Global entry via Tab key so HiveFocusRing is visible.
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump();
          await t.pump(HiveMotionTokens.standard.medium);
          // Hover over CI Check #0 so hover state layer is visible.
          final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
          hoverGesture = gesture;
          await gesture.addPointer(location: Offset.zero);
          await gesture.moveTo(t.getCenter(find.text('CI Check #0')));
          await t.pump();
          await t.pump(HiveMotionTokens.standard.medium);
        },
        afterCapture: () async {
          await hoverGesture?.removePointer();
        },
      );
    }

    // 11-12: Large text scale 1.6x (dark & light)
    for (final entry in themes.entries) {
      await _capture(
        tester,
        name: nextName('large_text_${entry.key}'),
        size: const Size(360, 820),
        theme: entry.value,
        child: const SideRailTree(currentLocation: '/overview'),
        workspaceRepo: populatedWsRepo,
        selectionStore: selectionStore,
        runsRepo: populatedRunsRepo,
        pauseRepo: populatedPauseRepo,
        fixedNow: fixedNow,
        textScale: 1.6,
        settle: false,
      );
    }

    // 13-14: Full AppShell at 1440x900 (dark & light)
    for (final entry in themes.entries) {
      await _capture(
        tester,
        name: nextName('app_shell_1440x900_${entry.key}'),
        size: const Size(1440, 900),
        theme: entry.value,
        child: const AppShell(
          location: '/overview',
          child: Center(child: Text('Workspace content area')),
        ),
        workspaceRepo: populatedWsRepo,
        selectionStore: selectionStore,
        runsRepo: populatedRunsRepo,
        pauseRepo: populatedPauseRepo,
        fixedNow: fixedNow,
        settle: false,
        beforeCapture: collapseWs3,
      );
    }
  });
}
