import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/shell/widgets/app_shell.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/side_rail_tree_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/side_rail_tree.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
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
      ? 'test/presentation/workspace/gallery'
      : 'frontend/test/presentation/workspace/gallery';
  Directory(dir).createSync(recursive: true);
  return '$dir/$name.png';
}

Future<void> _capture(
  WidgetTester tester, {
  required String name,
  required Size size,
  required Widget child,
  required FakeWorkspaceRepository workspaceRepo,
  required _FakeSelectionStore selectionStore,
  required _FakeRunsRepo runsRepo,
  required _FakePauseRepo pauseRepo,
  required DateTime fixedNow,
  double textScale = 1.0,
  bool settle = true,
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
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HiveTheme.dark(),
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
}

void main() {
  final fixedNow = DateTime.utc(2026, 11, 22, 12);

  setUpAll(_loadFonts);

  testWidgets('captures side rail tree wireframe gallery', (tester) async {
    final emptyWsRepo = FakeWorkspaceRepository();
    final emptyRunsRepo = _FakeRunsRepo();
    final emptyPauseRepo = _FakePauseRepo();
    final selectionStore = _FakeSelectionStore();

    // 1. Empty state
    await _capture(
      tester,
      name: '01_empty_desktop',
      size: const Size(360, 560),
      child: const SideRailTree(currentLocation: '/overview'),
      workspaceRepo: emptyWsRepo,
      selectionStore: selectionStore,
      runsRepo: emptyRunsRepo,
      pauseRepo: emptyPauseRepo,
      fixedNow: fixedNow,
    );

    // 2. Error state
    final errorWsRepo = FakeWorkspaceRepository()
      ..listWorkspacesFailure = const NetworkFailure('offline');
    await _capture(
      tester,
      name: '02_error_desktop',
      size: const Size(360, 560),
      child: const SideRailTree(currentLocation: '/overview'),
      workspaceRepo: errorWsRepo,
      selectionStore: selectionStore,
      runsRepo: emptyRunsRepo,
      pauseRepo: emptyPauseRepo,
      fixedNow: fixedNow,
    );

    // 3. Loading state
    final loadingWsRepo = FakeWorkspaceRepository()
      ..listWorkspacesGate = Completer<void>();
    await _capture(
      tester,
      name: '03_loading_desktop',
      size: const Size(360, 560),
      child: const SideRailTree(currentLocation: '/overview'),
      workspaceRepo: loadingWsRepo,
      selectionStore: selectionStore,
      runsRepo: emptyRunsRepo,
      pauseRepo: emptyPauseRepo,
      fixedNow: fixedNow,
      settle: false,
    );
    loadingWsRepo.listWorkspacesGate!.complete();

    // 4. Populated state (git + non-git, primary badge, dirty,
    // active + >3 recent, pending pause)
    final populatedWsRepo = FakeWorkspaceRepository()
      ..workspaces = <Workspace>[
        makeWorkspace(
          name: 'Agentic Hive',
          rootPath: '/repos/hive',
          activeRunCount: 2,
        ),
        makeWorkspace(
          id: 'ws-2',
          name: 'Docs',
          rootPath: '/docs/notes',
          isGit: false,
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

    await _capture(
      tester,
      name: '04_populated_desktop',
      size: const Size(360, 720),
      child: const SideRailTree(currentLocation: '/runs/run-active-1'),
      workspaceRepo: populatedWsRepo,
      selectionStore: selectionStore,
      runsRepo: populatedRunsRepo,
      pauseRepo: populatedPauseRepo,
      fixedNow: fixedNow,
    );

    // 5. Large text scale (1.6x)
    await _capture(
      tester,
      name: '05_large_text_desktop',
      size: const Size(360, 720),
      child: const SideRailTree(currentLocation: '/overview'),
      workspaceRepo: populatedWsRepo,
      selectionStore: selectionStore,
      runsRepo: populatedRunsRepo,
      pauseRepo: populatedPauseRepo,
      fixedNow: fixedNow,
      textScale: 1.6,
    );

    // 6. Full AppShell at 1440x900
    await _capture(
      tester,
      name: '06_app_shell_1440x900',
      size: const Size(1440, 900),
      child: const AppShell(
        location: '/overview',
        child: Center(child: Text('Workspace content area')),
      ),
      workspaceRepo: populatedWsRepo,
      selectionStore: selectionStore,
      runsRepo: populatedRunsRepo,
      pauseRepo: populatedPauseRepo,
      fixedNow: fixedNow,
    );
  });
}
