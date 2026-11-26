import 'dart:async';
import 'dart:io';

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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../workspace/fake_workspace_repository.dart';

final DateTime _baseTime = DateTime.utc(2026, 11, 21, 10);

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  String? savedId;

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async {
    savedId = workspaceId;
  }
}

List<Override> _workspaceOverrides() => <Override>[
  workspaceRepositoryProvider.overrideWithValue(
    FakeWorkspaceRepository(workspaces: <Workspace>[makeWorkspace()]),
  ),
  workspaceSelectionStoreProvider.overrideWithValue(_FakeSelectionStore()),
];

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

final class _FakeRunRepository implements RunRepository {
  final List<RunSummary> items = <RunSummary>[];

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async {
    final start = offset ?? 0;
    final page = limit == null
        ? items.skip(start).toList()
        : items.skip(start).take(limit).toList();
    return Success(RunsListResponse(items: page, total: items.length));
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
  new({required this.parentRun, this.checkpoints = const <Checkpoint>[]});

  final Run parentRun;
  final List<Checkpoint> checkpoints;
  final List<RunSummary> childSummaries = <RunSummary>[];
  final Map<String, Run> childRuns = <String, Run>{};

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
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
  }) async =>
      const Success(RunEventsResponse(items: <RunEvent>[], lastSequence: 0));

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

RunSummary _run({
  required String id,
  String workflowName = 'Pipeline',
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
  finishedAt: status.isActive ? null : DateTime.utc(2026, 11, 21, 10, 1),
  checkpointCount: 1,
  parentRunId: parentRunId,
  parentNodeId: parentNodeId,
);

Widget _buildRouterHost() {
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

  return MaterialApp.router(
    theme: HiveTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

Future<void> _pumpRunsPage(WidgetTester tester, _FakeRunRepository repo) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ..._workspaceOverrides(),
        runRepositoryProvider.overrideWithValue(repo),
        workflowRepositoryProvider.overrideWithValue(_FakeWorkflowRepository()),
      ],
      child: _buildRouterHost(),
    ),
  );
  await tester.pumpAndSettle();
}

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
  edges: const <WorkflowEdge>[],
  entryNodeId: 'planner',
  createdAt: _baseTime,
  updatedAt: _baseTime,
);

Run _parentRun() => Run(
  id: 'run-parent',
  workflowId: 'wf-parent',
  workflowName: 'Parent Flow',
  workflowDefinition: _fanOutWorkflow(),
  workspacePath: '/projects/hive',
  status: RunStatus.running,
  startedAt: _baseTime,
);

Run _childRun({
  required String id,
  required int index,
  RunStatus status = RunStatus.running,
  String? childName,
  DateTime? startedAt,
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
  workspacePath: '/projects/hive',
  status: status,
  startedAt: startedAt ?? _baseTime,
  parentRunId: 'run-parent',
  parentNodeId: 'fan',
  childIndex: index,
  childName: childName,
);

RunSummary _childSummary({
  required String id,
  RunStatus status = RunStatus.running,
  DateTime? startedAt,
}) => RunSummary(
  id: id,
  workspaceId: 'ws-1',
  workflowId: 'wf-child',
  workflowName: 'Child Flow',
  status: status,
  startedAt: startedAt ?? _baseTime,
  checkpointCount: 0,
  parentRunId: 'run-parent',
  parentNodeId: 'fan',
);

Future<void> _pumpDetailPage(
  WidgetTester tester,
  _FanOutRunRepository repo,
) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SizedBox.shrink());

  final ws = _FakeWsSession();
  addTearDown(ws.close);

  final router = GoRouter(
    initialLocation: '/runs/run-parent',
    routes: <RouteBase>[
      GoRoute(
        path: '/runs',
        builder: (_, _) => const Scaffold(body: Text('runs-list')),
      ),
      GoRoute(
        path: '/runs/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return Scaffold(body: RunDetailPage(runId: id));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        runRepositoryProvider.overrideWithValue(repo),
        backendWebSocketSessionProvider.overrideWithValue(ws),
        backendWsMessagesProvider.overrideWith((_) => ws.messages),
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
}

Future<void> _pumpPanel(WidgetTester tester, Widget panel) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: HiveTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
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
  );
}

File _resolveRepoFile(String relativeToFrontend) {
  final local = File(relativeToFrontend);
  if (local.existsSync()) return local;
  return File('frontend/$relativeToFrontend');
}

void main() {
  group('Run list fan-out structure guards', () {
    testWidgets(
      'parent row shows count and toggle, children hidden by default',
      (tester) async {
        final repo = _FakeRunRepository()
          ..items.addAll(<RunSummary>[
            _run(id: 'p1', workflowName: 'Parent Flow'),
            _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
            _run(id: 'c2', parentRunId: 'p1', parentNodeId: 'fan'),
          ]);
        await _pumpRunsPage(tester, repo);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(RunsPage)),
        )!;
        expect(find.byKey(const Key('run_children_count_p1')), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('run_children_count_p1')))
              .data,
          l10n.runsChildCount(2),
        );
        expect(find.text('2 child runs'), findsOneWidget);
        expect(find.byKey(const Key('run_children_toggle_p1')), findsOneWidget);
        expect(find.byKey(const Key('run_card_c1')), findsNothing);
        expect(find.byKey(const Key('run_card_c2')), findsNothing);
      },
    );

    testWidgets('one child says "1 child run"', (tester) async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'p1'),
          _run(id: 'c1', parentRunId: 'p1', parentNodeId: 'fan'),
        ]);
      await _pumpRunsPage(tester, repo);

      expect(find.text('1 child run'), findsOneWidget);
    });

    testWidgets(
      'expanded shows children in startedAt order, indented, without toggle',
      (tester) async {
        final repo = _FakeRunRepository()
          ..items.addAll(<RunSummary>[
            _run(
              id: 'c2',
              workflowName: 'Child Two',
              parentRunId: 'p1',
              parentNodeId: 'fan',
              startedAt: DateTime.utc(2026, 11, 21, 10, 2),
            ),
            _run(id: 'p1', workflowName: 'Parent'),
            _run(
              id: 'c1',
              workflowName: 'Child One',
              parentRunId: 'p1',
              parentNodeId: 'fan',
              startedAt: DateTime.utc(2026, 11, 21, 10, 1),
            ),
          ]);
        await _pumpRunsPage(tester, repo);

        await tester.tap(find.byKey(const Key('run_children_toggle_p1')));
        await tester.pumpAndSettle();

        final p1Pos = tester.getTopLeft(find.byKey(const Key('run_card_p1')));
        final c1Pos = tester.getTopLeft(find.byKey(const Key('run_card_c1')));
        final c2Pos = tester.getTopLeft(find.byKey(const Key('run_card_c2')));

        expect(c1Pos.dy, greaterThan(p1Pos.dy));
        expect(c2Pos.dy, greaterThan(c1Pos.dy));
        expect(c1Pos.dx, greaterThan(p1Pos.dx));
        expect(c2Pos.dx, greaterThan(p1Pos.dx));
        expect(find.byKey(const Key('run_children_toggle_c1')), findsNothing);
        expect(find.byKey(const Key('run_children_toggle_c2')), findsNothing);
      },
    );

    testWidgets('child with unloaded parent stays top level', (tester) async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(
            id: 'orphan',
            workflowName: 'Orphan',
            parentRunId: 'missing',
            parentNodeId: 'fan',
          ),
          _run(id: 'solo', workflowName: 'Standalone'),
        ]);
      await _pumpRunsPage(tester, repo);

      final orphanLeft = tester.getTopLeft(
        find.byKey(const Key('run_card_orphan')),
      );
      final soloLeft = tester.getTopLeft(
        find.byKey(const Key('run_card_solo')),
      );
      expect(orphanLeft.dx, soloLeft.dx);
    });

    testWidgets('delete icon only on non-active rows', (tester) async {
      final repo = _FakeRunRepository()
        ..items.addAll(<RunSummary>[
          _run(id: 'done-run'),
          _run(id: 'active-run', status: RunStatus.running),
        ]);
      await _pumpRunsPage(tester, repo);

      expect(find.byKey(const Key('run_delete_done-run')), findsOneWidget);
      expect(find.byKey(const Key('run_delete_active-run')), findsNothing);
    });
  });

  group('Canvas fan-out card structure guards', () {
    testWidgets('canvas card subtitle shows progress', (tester) async {
      final repoWithChildren =
          _FanOutRunRepository(
              parentRun: _parentRun(),
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
                      'data': <String, Object?>{'total': 2},
                    },
                  },
                  createdAt: _baseTime,
                ),
              ],
            )
            ..childSummaries.addAll(<RunSummary>[
              _childSummary(id: 'c0', status: RunStatus.failed),
              _childSummary(id: 'c1', status: RunStatus.succeeded),
            ])
            ..childRuns['c0'] = _childRun(
              id: 'c0',
              index: 0,
              status: RunStatus.failed,
            )
            ..childRuns['c1'] = _childRun(
              id: 'c1',
              index: 1,
              status: RunStatus.succeeded,
            );
      await _pumpDetailPage(tester, repoWithChildren);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RunDetailPage)),
      )!;
      const progressKey = Key('run_graph_node_progress_fan');
      expect(find.byKey(progressKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(progressKey)).data,
        l10n.runDetailFanOutProgress(2, 2, 1),
      );

      final repoEmpty = _FanOutRunRepository(
        parentRun: _parentRun(),
        checkpoints: <Checkpoint>[
          Checkpoint(
            id: 'cp-empty',
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
      await _pumpDetailPage(tester, repoEmpty);
      expect(find.byKey(progressKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(progressKey)).data,
        l10n.runDetailFanOutNoItems,
      );

      final repoNone = _FanOutRunRepository(parentRun: _parentRun());
      await _pumpDetailPage(tester, repoNone);
      expect(find.byKey(progressKey), findsNothing);
      expect(find.text(l10n.nodeTypeFanOut), findsOneWidget);
    });

    testWidgets('canvas card has no needs-you text on screen', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final repo = _FanOutRunRepository(parentRun: _parentRun())
          ..childSummaries.add(
            _childSummary(id: 'c0', status: RunStatus.paused),
          )
          ..childRuns['c0'] = _childRun(
            id: 'c0',
            index: 0,
            status: RunStatus.paused,
          );
        await _pumpDetailPage(tester, repo);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(RunDetailPage)),
        )!;
        expect(find.byKey(const Key('fan_out_needs_you_badge')), findsNothing);
        expect(find.text(l10n.runDetailFanOutNeedsYou(1)), findsNothing);
        expect(
          find.bySemanticsLabel(
            RegExp(
              'Fan Out.*${RegExp.escape(l10n.runDetailFanOutNeedsYou(1))}',
            ),
          ),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('FanOutChildrenPanel structure guards', () {
    testWidgets('panel states', (tester) async {
      await _pumpPanel(
        tester,
        FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.running,
          progress: null,
          isLoading: true,
          loadFailed: false,
          failureMessage: null,
          onOpenRun: (_) {},
          onRetry: () {},
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('fan_out_loading')), findsOneWidget);

      await _pumpPanel(
        tester,
        FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.running,
          progress: null,
          isLoading: false,
          loadFailed: true,
          failureMessage: null,
          onOpenRun: (_) {},
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fan_out_load_error')), findsOneWidget);
      expect(find.byKey(const Key('fan_out_retry_button')), findsOneWidget);

      await _pumpPanel(
        tester,
        FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.succeeded,
          progress: const FanOutProgress(
            items: <FanOutItem>[],
            emptyList: true,
          ),
          isLoading: false,
          loadFailed: false,
          failureMessage: null,
          onOpenRun: (_) {},
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fan_out_empty_note')), findsOneWidget);
      expect(find.text('No items'), findsOneWidget);

      await _pumpPanel(
        tester,
        FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.failed,
          progress: const FanOutProgress(items: <FanOutItem>[]),
          isLoading: false,
          loadFailed: false,
          failureMessage: "Items path 'issues' is not a list",
          onOpenRun: (_) {},
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fan_out_failed_banner')), findsOneWidget);
      expect(find.text("Items path 'issues' is not a list"), findsOneWidget);

      await _pumpPanel(
        tester,
        FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.failed,
          progress: const FanOutProgress(items: <FanOutItem>[]),
          isLoading: false,
          loadFailed: false,
          failureMessage: null,
          onOpenRun: (_) {},
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(FanOutChildrenPanel)),
      )!;
      expect(find.byKey(const Key('fan_out_failed_banner')), findsOneWidget);
      expect(find.text(l10n.runDetailFanOutFailedGeneric), findsOneWidget);

      await _pumpPanel(
        tester,
        FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.running,
          progress: const FanOutProgress(
            items: <FanOutItem>[
              FanOutItem(
                index: 0,
                name: 'Item A',
                status: RunStatus.succeeded,
                runId: 'r0',
              ),
              FanOutItem(
                index: 1,
                name: 'Item B',
                status: RunStatus.running,
                runId: 'r1',
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
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fan_out_progress_text')), findsOneWidget);
      expect(find.byKey(const Key('fan_out_child_0')), findsOneWidget);
      expect(find.byKey(const Key('fan_out_child_1')), findsOneWidget);
    });

    testWidgets('panel needs-you badge and child badges', (tester) async {
      final openedIds = <String>[];
      await _pumpPanel(
        tester,
        FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.running,
          progress: const FanOutProgress(
            items: <FanOutItem>[
              FanOutItem(
                index: 0,
                name: 'Paused child',
                status: RunStatus.paused,
                runId: 'run-paused',
              ),
              FanOutItem(
                index: 1,
                name: 'Deleted child',
                status: RunStatus.succeeded,
                runId: 'run-deleted',
                deleted: true,
              ),
              FanOutItem(
                index: 2,
                name: 'Blocked child',
                status: RunStatus.failed,
              ),
            ],
          ),
          isLoading: false,
          loadFailed: false,
          failureMessage: null,
          onOpenRun: openedIds.add,
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fan_out_needs_you_badge')), findsOneWidget);
      expect(find.text('1 child needs you'), findsOneWidget);
      expect(find.byKey(const Key('fan_out_child_deleted_1')), findsOneWidget);
      expect(find.text('Deleted'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fan_out_child_0')));
      await tester.tap(find.byKey(const Key('fan_out_child_1')));
      await tester.tap(find.byKey(const Key('fan_out_child_2')));
      await tester.pumpAndSettle();

      expect(openedIds, <String>['run-paused']);
    });

    testWidgets('panel row order', (tester) async {
      await _pumpPanel(
        tester,
        FanOutChildrenPanel(
          nodeStatus: HiveNodeStatus.running,
          progress: const FanOutProgress(
            items: <FanOutItem>[
              FanOutItem(
                index: 0,
                name: 'First',
                status: RunStatus.succeeded,
                runId: 'r0',
              ),
              FanOutItem(
                index: 1,
                name: 'Second',
                status: RunStatus.running,
                runId: 'r1',
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
      await tester.pumpAndSettle();

      final progressDy = tester
          .getTopLeft(find.byKey(const Key('fan_out_progress_text')))
          .dy;
      final child0Dy = tester
          .getTopLeft(find.byKey(const Key('fan_out_child_0')))
          .dy;
      final child1Dy = tester
          .getTopLeft(find.byKey(const Key('fan_out_child_1')))
          .dy;

      expect(child0Dy, greaterThan(progressDy));
      expect(child1Dy, greaterThan(child0Dy));
    });
  });

  test('token guard', () {
    const configDir = 'lib/presentation/workflows/widgets/node_config_forms';
    const files = <String>[
      'lib/presentation/runs/widgets/run_list_card.dart',
      'lib/presentation/runs/widgets/fan_out_children_panel.dart',
      '$configDir/fan_out_config_form.dart',
      '$configDir/fan_out_workflow_select_field.dart',
      'lib/presentation/pauses/widgets/pause_list_pane.dart',
      'lib/presentation/pauses/widgets/pause_detail_pane.dart',
    ];
    final bannedPatterns = <RegExp>[
      RegExp(r'Color\(0x'),
      RegExp(r'\bColors\.'),
      RegExp(r'EdgeInsets\.[a-zA-Z]+\(\s*\d'),
      RegExp(r'SizedBox\((width|height):\s*\d'),
      RegExp(r'BorderRadius\.circular\(\s*\d'),
      RegExp(r'fontSize:\s*\d'),
      RegExp(r'\bDuration\('),
    ];

    for (final path in files) {
      final file = _resolveRepoFile(path);
      expect(file.existsSync(), isTrue, reason: 'Missing file: $path');
      final source = file.readAsStringSync();
      for (final pattern in bannedPatterns) {
        expect(
          pattern.hasMatch(source),
          isFalse,
          reason: '$path matched banned pattern ${pattern.pattern}',
        );
      }
      expect(
        source.contains('package:flutter/material.dart'),
        isFalse,
        reason: '$path imports package:flutter/material.dart',
      );
      expect(
        source.contains('hugeicons'),
        isFalse,
        reason: '$path imports hugeicons',
      );
    }
  });
}
