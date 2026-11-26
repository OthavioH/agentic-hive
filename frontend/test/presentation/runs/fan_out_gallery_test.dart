import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/fan_out_progress.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/fan_out_children_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../workspace/fake_workspace_repository.dart';

const String _captureDir = String.fromEnvironment('HIVE_CAPTURE_DIR');
final DateTime _baseTime = DateTime.utc(2026, 11, 21, 10);

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

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  String? savedId;

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async {
    savedId = workspaceId;
  }
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success(<WorkflowSummary>[]);

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) => const Stream<WorkflowDeletionUpdate>.empty();

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

final class _FakeWsSession implements BackendWebSocketSession {
  final StreamController<WsEnvelope> _messages =
      StreamController<WsEnvelope>.broadcast();
  final Completer<void> _done = Completer<void>();

  @override
  ServerHelloPayload get serverHello => const ServerHelloPayload(
    protocolVersion: wsProtocolVersion,
    serverVersion: '0.1.0',
  );

  @override
  Stream<WsEnvelope> get messages => _messages.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => false;

  @override
  Future<Result<void>> send(WsEnvelope envelope) async => const Success(null);

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!_done.isCompleted) _done.complete();
    await _messages.close();
  }
}

final class _FakeRunListRepository implements RunRepository {
  new(this.items);

  final List<RunSummary> items;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async {
    final filtered = workspaceId == null
        ? items
        : items.where((r) => r.workspaceId == workspaceId).toList();
    return Success(RunsListResponse(items: filtered, total: filtered.length));
  }

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
  Future<Result<Run>> startRun(StartRunRequest request) async =>
      const FailureResult(NotFoundFailure('unused'));

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

final class _FanOutRunRepository implements RunRepository {
  new({
    required this.parentRun,
    this.checkpoints = const <Checkpoint>[],
    this.events = const <RunEvent>[],
  });

  final Run parentRun;
  final List<Checkpoint> checkpoints;
  final List<RunEvent> events;
  final List<RunSummary> childSummaries = <RunSummary>[];
  final Map<String, Run> childRuns = <String, Run>{};

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async {
    return Success(
      RunsListResponse(items: childSummaries, total: childSummaries.length),
    );
  }

  @override
  Future<Result<Run>> getRun(String id) async {
    if (id == parentRun.id) return Success(parentRun);
    final child = childRuns[id];
    if (child != null) return Success(child);
    return const FailureResult(NotFoundFailure('missing'));
  }

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => Success(
    RunEventsResponse(
      items: events,
      lastSequence: events.isEmpty ? 0 : events.last.sequence,
    ),
  );

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      Success(checkpoints);

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async =>
      const FailureResult(NotFoundFailure('unused'));

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
  }) async => Success(
    RunNodeLogsResponse(runId: id, nodeId: nodeId, attempt: attempt ?? 1),
  );

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

RunSummary _runSummary({
  required String id,
  String workflowName = 'Release Pipeline',
  RunStatus status = RunStatus.succeeded,
  DateTime? startedAt,
  String? parentRunId,
  String? parentNodeId,
}) => RunSummary(
  id: id,
  workspaceId: 'ws-1',
  workflowId: 'wf-1',
  workflowName: workflowName,
  status: status,
  startedAt: startedAt ?? _baseTime,
  finishedAt: status.isActive ? null : DateTime.utc(2026, 11, 21, 10, 2),
  checkpointCount: 2,
  parentRunId: parentRunId,
  parentNodeId: parentNodeId,
);

List<RunSummary> _runsListSample() => <RunSummary>[
  _runSummary(
    id: 'p1',
    workflowName: 'Issue Triage Batch',
    status: RunStatus.running,
  ),
  _runSummary(
    id: 'c1',
    workflowName: 'Process Issue #101',
    parentRunId: 'p1',
    parentNodeId: 'fan',
    startedAt: DateTime.utc(2026, 11, 21, 10, 1),
  ),
  _runSummary(
    id: 'c2',
    workflowName: 'Process Issue #102',
    status: RunStatus.failed,
    parentRunId: 'p1',
    parentNodeId: 'fan',
    startedAt: DateTime.utc(2026, 11, 21, 10, 2),
  ),
  _runSummary(
    id: 'c3',
    workflowName: 'Process Issue #103 with a notably long child workflow name',
    status: RunStatus.running,
    parentRunId: 'p1',
    parentNodeId: 'fan',
    startedAt: DateTime.utc(2026, 11, 21, 10, 3),
  ),
  _runSummary(id: 'solo', workflowName: 'Nightly Build'),
  _runSummary(
    id: 'orphan',
    workflowName: 'Orphaned Child Run',
    status: RunStatus.paused,
    parentRunId: 'missing-parent',
    parentNodeId: 'fan',
    startedAt: DateTime.utc(2026, 11, 21, 10, 4),
  ),
];

Workflow _fanOutWorkflow() => Workflow(
  id: 'wf-parent',
  name: 'Parent Flow',
  nodes: const <WorkflowNode>[
    WorkflowNode(
      id: 'planner',
      type: NodeTypeId.claudeCode,
      label: 'Planner',
      position: WorkflowPosition(x: 40, y: 100),
    ),
    WorkflowNode(
      id: 'fan',
      type: NodeTypeId.fanOut,
      label: 'Fan Out',
      config: <String, Object?>{
        'workflowId': 'wf-child',
        'itemsNodeId': 'planner',
        'itemsPath': 'items',
      },
      position: WorkflowPosition(x: 300, y: 100),
    ),
  ],
  edges: const <WorkflowEdge>[
    WorkflowEdge(
      id: 'e1',
      sourceNodeId: 'planner',
      targetNodeId: 'fan',
      sourceOutput: NodeOutput.onSuccess,
    ),
  ],
  entryNodeId: 'planner',
  createdAt: _baseTime,
  updatedAt: _baseTime,
);

Run _parentRun({RunStatus status = RunStatus.running}) => Run(
  id: 'run-parent',
  workflowId: 'wf-parent',
  workflowName: 'Parent Flow',
  workflowDefinition: _fanOutWorkflow(),
  workspaceRoot: '/projects/hive',
  status: status,
  startedAt: _baseTime,
);

Run _childRun({
  required String id,
  required int index,
  RunStatus status = RunStatus.running,
  String? childName,
}) => Run(
  id: id,
  workflowId: 'wf-child',
  workflowName: 'Child Flow',
  workflowDefinition: Workflow(
    id: 'wf-child',
    name: 'Child Flow',
    nodes: const <WorkflowNode>[],
    edges: const <WorkflowEdge>[],
    createdAt: _baseTime,
    updatedAt: _baseTime,
  ),
  workspaceRoot: '/projects/hive',
  status: status,
  startedAt: _baseTime.add(Duration(minutes: index)),
  parentRunId: 'run-parent',
  parentNodeId: 'fan',
  childIndex: index,
  childName: childName,
);

RunSummary _childSummary({
  required String id,
  RunStatus status = RunStatus.running,
}) => RunSummary(
  id: id,
  workspaceId: 'ws-1',
  workflowId: 'wf-child',
  workflowName: 'Child Flow',
  status: status,
  startedAt: _baseTime,
  checkpointCount: 0,
  parentRunId: 'run-parent',
  parentNodeId: 'fan',
);

Future<void> _saveCapture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String id,
  String themeName,
  Size size,
) async {
  expect(tester.takeException(), isNull);
  Directory(_captureDir).createSync(recursive: true);
  final dims = '${size.width.toInt()}x${size.height.toInt()}';
  final outPath = p.join(_captureDir, '${id}_${themeName}_$dims.png');
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    File(outPath).writeAsBytesSync(byteData!.buffer.asUint8List());
  });
  expect(File(outPath).existsSync(), isTrue);
}

Future<void> _captureRunsList(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  Future<void> Function(WidgetTester tester)? drive,
  double textScale = 1.0,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const SizedBox.shrink());
  final repo = _FakeRunListRepository(_runsListSample());
  final router = GoRouter(
    initialLocation: '/runs',
    routes: <RouteBase>[
      GoRoute(
        path: '/runs',
        builder: (_, _) => const Scaffold(body: RunsPage()),
      ),
    ],
  );
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        workspaceRepositoryProvider.overrideWithValue(
          FakeWorkspaceRepository(workspaces: <Workspace>[makeWorkspace()]),
        ),
        workspaceSelectionStoreProvider.overrideWithValue(
          _FakeSelectionStore(),
        ),
        runRepositoryProvider.overrideWithValue(repo),
        workflowRepositoryProvider.overrideWithValue(_FakeWorkflowRepository()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (drive != null) {
    await drive(tester);
  }

  await _saveCapture(tester, boundaryKey, id, themeName, size);
  handle.dispose();
}

Future<void> _captureDetail(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  required _FanOutRunRepository repo,
  Future<void> Function(WidgetTester tester)? drive,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const SizedBox.shrink());
  final ws = _FakeWsSession();
  addTearDown(ws.close);
  final router = GoRouter(
    initialLocation: '/runs/run-parent',
    routes: <RouteBase>[
      GoRoute(
        path: '/runs',
        builder: (_, _) => const Scaffold(body: Text('runs')),
      ),
      GoRoute(
        path: '/runs/:id',
        builder: (_, state) =>
            Scaffold(body: RunDetailPage(runId: state.pathParameters['id']!)),
      ),
    ],
  );
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        runRepositoryProvider.overrideWithValue(repo),
        backendWebSocketSessionProvider.overrideWithValue(ws),
        backendWsMessagesProvider.overrideWith((_) => ws.messages),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (drive != null) {
    await drive(tester);
  }

  await _saveCapture(tester, boundaryKey, id, themeName, size);
  handle.dispose();
}

Future<void> _capturePanel(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  required FanOutChildrenPanel panel,
  double textScale = 1.0,
  bool waitSettle = true,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const SizedBox.shrink());
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) {
              final spacing = context.hiveSpacing;
              return SizedBox(
                width: spacing.space6 * 10,
                height: spacing.space8 * 10,
                child: panel,
              );
            },
          ),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(key: boundaryKey, child: child),
      ),
    ),
  );
  if (waitSettle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }

  await _saveCapture(tester, boundaryKey, id, themeName, size);
  handle.dispose();
}

_FanOutRunRepository _runningRepo() {
  final repo = _FanOutRunRepository(parentRun: _parentRun());
  final statuses = <RunStatus>[
    RunStatus.succeeded,
    RunStatus.succeeded,
    RunStatus.succeeded,
    RunStatus.failed,
    RunStatus.running,
  ];
  for (var i = 0; i < statuses.length; i++) {
    final id = 'c$i';
    repo.childSummaries.add(_childSummary(id: id, status: statuses[i]));
    repo.childRuns[id] = _childRun(
      id: id,
      index: i,
      status: statuses[i],
      childName: 'Issue #${100 + i}',
    );
  }
  return repo;
}

_FanOutRunRepository _needsYouRepo() {
  return _FanOutRunRepository(parentRun: _parentRun())
    ..childSummaries.addAll(<RunSummary>[
      _childSummary(id: 'c0', status: RunStatus.succeeded),
      _childSummary(id: 'c1', status: RunStatus.paused),
    ])
    ..childRuns['c0'] = _childRun(
      id: 'c0',
      index: 0,
      status: RunStatus.succeeded,
      childName: 'Issue #101',
    )
    ..childRuns['c1'] = _childRun(
      id: 'c1',
      index: 1,
      status: RunStatus.paused,
      childName: 'Issue #102',
    );
}

_FanOutRunRepository _emptyRepo() {
  return _FanOutRunRepository(
    parentRun: _parentRun(status: RunStatus.succeeded),
    checkpoints: <Checkpoint>[
      Checkpoint(
        id: 'cp-1',
        runId: 'run-parent',
        sequence: 1,
        completedNodeId: 'fan',
        pendingNodeIds: const <String>[],
        attemptsByEdge: const <String, int>{},
        circuitBreakerCount: 0,
        nodeOutputs: const <String, JsonMap>{
          'fan': <String, Object?>{
            'data': <String, Object?>{'total': 0},
          },
        },
        createdAt: _baseTime,
      ),
    ],
  );
}

_FanOutRunRepository _failedRepo() {
  return _FanOutRunRepository(
    parentRun: _parentRun(status: RunStatus.failed),
    events: <RunEvent>[
      RunEvent(
        id: 'ev-1',
        runId: 'run-parent',
        sequence: 1,
        type: RunEventType.nodeFailed,
        nodeId: 'fan',
        payload: const <String, Object?>{
          'message': "Items path 'issues' is not a list",
        },
        createdAt: _baseTime,
      ),
    ],
  );
}

void main() {
  if (_captureDir.isEmpty) {
    test(
      'capture skipped without HIVE_CAPTURE_DIR',
      () {},
      skip: 'set --dart-define=HIVE_CAPTURE_DIR=<dir>',
    );
    return;
  }

  setUpAll(_loadFonts);

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  final themes = <String, ThemeData>{
    'dark': HiveTheme.dark(),
    'light': HiveTheme.light(),
  };
  const sizes = <Size>[Size(1280, 720), Size(1440, 900)];

  for (final themeEntry in themes.entries) {
    final themeName = themeEntry.key;
    final theme = themeEntry.value;

    for (final size in sizes) {
      final dims = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('capture runs-collapsed ($themeName $dims)', (tester) async {
        await _captureRunsList(
          tester,
          id: 'runs-collapsed',
          themeName: themeName,
          theme: theme,
          size: size,
        );
      });

      testWidgets('capture runs-expanded ($themeName $dims)', (tester) async {
        await _captureRunsList(
          tester,
          id: 'runs-expanded',
          themeName: themeName,
          theme: theme,
          size: size,
          drive: (tester) async {
            await tester.tap(find.byKey(const Key('run_children_toggle_p1')));
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('capture runs-toggle-hover ($themeName $dims)', (
        tester,
      ) async {
        await _captureRunsList(
          tester,
          id: 'runs-toggle-hover',
          themeName: themeName,
          theme: theme,
          size: size,
          drive: (tester) async {
            final toggle = find.byKey(const Key('run_children_toggle_p1'));
            final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
            addTearDown(g.removePointer);
            await g.addPointer(location: Offset.zero);
            await g.moveTo(tester.getCenter(toggle));
            await tester.pump();
          },
        );
      });

      testWidgets('capture runs-toggle-focus ($themeName $dims)', (
        tester,
      ) async {
        await _captureRunsList(
          tester,
          id: 'runs-toggle-focus',
          themeName: themeName,
          theme: theme,
          size: size,
          drive: (tester) async {
            final toggle = find.byKey(const Key('run_children_toggle_p1'));
            final iconFinder = find.descendant(
              of: toggle,
              matching: find.byType(HiveIcon),
            );
            final targetNode = Focus.of(tester.element(iconFinder.first));
            for (var i = 0; i < 30 && !targetNode.hasFocus; i++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pump();
            }
            if (!targetNode.hasFocus) {
              targetNode.requestFocus();
              await tester.pumpAndSettle();
            }
          },
        );
      });

      testWidgets('capture canvas-running ($themeName $dims)', (tester) async {
        await _captureDetail(
          tester,
          id: 'canvas-running',
          themeName: themeName,
          theme: theme,
          size: size,
          repo: _runningRepo(),
        );
      });

      testWidgets('capture canvas-needs-you ($themeName $dims)', (
        tester,
      ) async {
        await _captureDetail(
          tester,
          id: 'canvas-needs-you',
          themeName: themeName,
          theme: theme,
          size: size,
          repo: _needsYouRepo(),
          drive: (tester) async {
            await tester.tap(find.byKey(const Key('run_graph_node_fan')));
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('capture canvas-empty ($themeName $dims)', (tester) async {
        await _captureDetail(
          tester,
          id: 'canvas-empty',
          themeName: themeName,
          theme: theme,
          size: size,
          repo: _emptyRepo(),
        );
      });

      testWidgets('capture canvas-failed ($themeName $dims)', (tester) async {
        await _captureDetail(
          tester,
          id: 'canvas-failed',
          themeName: themeName,
          theme: theme,
          size: size,
          repo: _failedRepo(),
          drive: (tester) async {
            await tester.tap(find.byKey(const Key('run_graph_node_fan')));
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('capture panel-loading ($themeName $dims)', (tester) async {
        await _capturePanel(
          tester,
          id: 'panel-loading',
          themeName: themeName,
          theme: theme,
          size: size,
          waitSettle: false,
          panel: FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: null,
            isLoading: true,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        );
      });

      testWidgets('capture panel-load-error ($themeName $dims)', (
        tester,
      ) async {
        await _capturePanel(
          tester,
          id: 'panel-load-error',
          themeName: themeName,
          theme: theme,
          size: size,
          panel: FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: null,
            isLoading: false,
            loadFailed: true,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        );
      });

      testWidgets('capture panel-deleted-notstarted ($themeName $dims)', (
        tester,
      ) async {
        await _capturePanel(
          tester,
          id: 'panel-deleted-notstarted',
          themeName: themeName,
          theme: theme,
          size: size,
          panel: FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.failed,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 0,
                  name: 'Issue #1',
                  status: RunStatus.succeeded,
                  runId: 'r0',
                ),
                FanOutItem(
                  index: 1,
                  name: 'Issue #2',
                  status: RunStatus.succeeded,
                  runId: 'r1',
                  deleted: true,
                ),
                FanOutItem(
                  index: 2,
                  name: 'Issue #3',
                  status: RunStatus.failed,
                ),
                FanOutItem(
                  index: 3,
                  name: 'Issue #4',
                  status: RunStatus.failed,
                  runId: 'r3',
                ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        );
      });

      testWidgets('capture panel-many ($themeName $dims)', (tester) async {
        await _capturePanel(
          tester,
          id: 'panel-many',
          themeName: themeName,
          theme: theme,
          size: size,
          panel: FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: FanOutProgress(
              items: <FanOutItem>[
                for (var i = 0; i < 12; i++)
                  FanOutItem(
                    index: i,
                    name: 'Work item #${i + 1}',
                    status: i < 6
                        ? RunStatus.succeeded
                        : (i == 6 ? RunStatus.failed : RunStatus.running),
                    runId: 'r$i',
                  ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        );
      });

      testWidgets('capture panel-long-names ($themeName $dims)', (
        tester,
      ) async {
        await _capturePanel(
          tester,
          id: 'panel-long-names',
          themeName: themeName,
          theme: theme,
          size: size,
          panel: FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 0,
                  name:
                      'Refactor authentication token refresh middleware across '
                      'desktop and background daemon endpoints',
                  status: RunStatus.paused,
                  runId: 'r0',
                ),
                FanOutItem(
                  index: 1,
                  name:
                      'Migrate persisted workflow snapshots without breaking '
                      'existing paused executions',
                  status: RunStatus.succeeded,
                  runId: 'r1',
                  deleted: true,
                ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        );
      });
    }

    testWidgets('capture runs-expanded-large ($themeName 1280x720)', (
      tester,
    ) async {
      await _captureRunsList(
        tester,
        id: 'runs-expanded-large',
        themeName: themeName,
        theme: theme,
        size: sizes.first,
        textScale: 2,
        drive: (tester) async {
          await tester.tap(find.byKey(const Key('run_children_toggle_p1')));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('capture panel-large ($themeName 1280x720)', (tester) async {
      await _capturePanel(
        tester,
        id: 'panel-large',
        themeName: themeName,
        theme: theme,
        size: sizes.first,
        textScale: 2,
        panel: FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.running,
          progress: const FanOutProgress(
            items: <FanOutItem>[
              FanOutItem(
                index: 0,
                name: 'Issue #101',
                status: RunStatus.succeeded,
                runId: 'r0',
              ),
              FanOutItem(
                index: 1,
                name: 'Issue #102',
                status: RunStatus.paused,
                runId: 'r1',
              ),
              FanOutItem(
                index: 2,
                name: 'Issue #103',
                status: RunStatus.succeeded,
                runId: 'r2',
                deleted: true,
              ),
            ],
          ),
          isLoading: false,
          loadFailed: false,
          failureMessage: null,
          onOpenRun: (_) {},
          onRetry: () {},
        ),
      );
    });
  }
}
