import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/fan_out_progress.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/fan_out_children_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final DateTime _baseTime = DateTime.utc(2026, 11, 21, 10);

Widget _wrapPanel(Widget child) {
  return MaterialApp(
    theme: HiveTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
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

final class _FanOutRunRepository implements RunRepository {
  new({required this.parentRun, this.checkpoints = const <Checkpoint>[]});

  final Run parentRun;
  final List<Checkpoint> checkpoints;
  final List<RunSummary> childSummaries = <RunSummary>[];
  final Map<String, Run> childRuns = <String, Run>{};
  int listRunsCalls = 0;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async {
    listRunsCalls++;
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

Workflow _fanOutWorkflow({bool includeFanOut = true}) {
  final nodes = <WorkflowNode>[
    const WorkflowNode(
      id: 'planner',
      type: NodeTypeId.claudeCode,
      label: 'Planner',
      position: WorkflowPosition(x: 40, y: 100),
    ),
    if (includeFanOut)
      const WorkflowNode(
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
  ];
  return Workflow(
    id: 'wf-parent',
    name: 'Parent Flow',
    nodes: nodes,
    edges: const <WorkflowEdge>[],
    entryNodeId: 'planner',
    createdAt: _baseTime,
    updatedAt: _baseTime,
  );
}

Run _parentRun({bool includeFanOut = true}) => Run(
  id: 'run-parent',
  workflowId: 'wf-parent',
  workflowName: 'Parent Flow',
  workflowDefinition: _fanOutWorkflow(includeFanOut: includeFanOut),
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

Future<void> _pumpPage(
  WidgetTester tester,
  _FanOutRunRepository repo, {
  List<String>? navigated,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
          if (id != 'run-parent') {
            navigated?.add('/runs/$id');
            return Scaffold(body: Text('child-detail:$id'));
          }
          return Scaffold(body: RunDetailPage(runId: id));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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

void main() {
  group('FanOutChildrenPanel', () {
    testWidgets('running shows progress text', (tester) async {
      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 0,
                  name: 'A',
                  status: RunStatus.succeeded,
                  runId: 'r0',
                ),
                FanOutItem(
                  index: 1,
                  name: 'B',
                  status: RunStatus.succeeded,
                  runId: 'r1',
                ),
                FanOutItem(
                  index: 2,
                  name: 'C',
                  status: RunStatus.failed,
                  runId: 'r2',
                ),
                FanOutItem(
                  index: 3,
                  name: 'D',
                  status: RunStatus.running,
                  runId: 'r3',
                ),
                FanOutItem(
                  index: 4,
                  name: 'E',
                  status: RunStatus.running,
                  runId: 'r4',
                ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3/5 done, 1 failed'), findsOneWidget);

      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 0,
                  name: 'A',
                  status: RunStatus.succeeded,
                  runId: 'r0',
                ),
                FanOutItem(
                  index: 1,
                  name: 'B',
                  status: RunStatus.succeeded,
                  runId: 'r1',
                ),
                FanOutItem(
                  index: 2,
                  name: 'C',
                  status: RunStatus.running,
                  runId: 'r2',
                ),
                FanOutItem(
                  index: 3,
                  name: 'D',
                  status: RunStatus.running,
                  runId: 'r3',
                ),
                FanOutItem(
                  index: 4,
                  name: 'E',
                  status: RunStatus.running,
                  runId: 'r4',
                ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2/5 done'), findsOneWidget);
    });

    testWidgets('paused child shows the needs-you badge', (tester) async {
      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 0,
                  name: 'A',
                  status: RunStatus.paused,
                  runId: 'r0',
                ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fan_out_needs_you_badge')), findsOneWidget);
      expect(find.text('1 child needs you'), findsOneWidget);

      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 0,
                  name: 'A',
                  status: RunStatus.paused,
                  runId: 'r0',
                ),
                FanOutItem(
                  index: 1,
                  name: 'B',
                  status: RunStatus.paused,
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
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 children need you'), findsOneWidget);
    });

    testWidgets('empty list shows "No items"', (tester) async {
      await tester.pumpWidget(
        _wrapPanel(
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
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fan_out_empty_note')), findsOneWidget);
      expect(find.text('No items'), findsOneWidget);
      expect(find.byKey(const Key('fan_out_progress_text')), findsNothing);
    });

    testWidgets('failed before start shows the backend message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.failed,
            progress: const FanOutProgress(items: <FanOutItem>[]),
            isLoading: false,
            loadFailed: false,
            failureMessage: 'Path "issues" was not a list.',
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fan_out_failed_banner')), findsOneWidget);
      expect(find.text('Path "issues" was not a list.'), findsOneWidget);

      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.failed,
            progress: const FanOutProgress(items: <FanOutItem>[]),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The fan-out node failed.'), findsOneWidget);
    });

    testWidgets('deleted child is listed as Deleted and is not tappable', (
      tester,
    ) async {
      String? openedId;
      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.succeeded,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 0,
                  name: 'Old item',
                  status: RunStatus.succeeded,
                  runId: 'r1',
                  deleted: true,
                ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (id) => openedId = id,
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fan_out_child_deleted_0')), findsOneWidget);
      expect(find.text('Deleted'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fan_out_child_0')));
      await tester.pumpAndSettle();
      expect(openedId, isNull);
    });

    testWidgets('not started child shows Not started', (tester) async {
      String? openedId;
      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.failed,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(index: 0, name: 'Blocked', status: RunStatus.failed),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (id) => openedId = id,
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not started'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fan_out_child_0')));
      await tester.pumpAndSettle();
      expect(openedId, isNull);
    });

    testWidgets('tapping an openable child calls onOpenRun with its run id', (
      tester,
    ) async {
      String? openedId;
      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 0,
                  name: 'First',
                  status: RunStatus.running,
                  runId: 'run-child-1',
                ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (id) => openedId = id,
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fan_out_child_0')));
      await tester.pumpAndSettle();
      expect(openedId, 'run-child-1');
    });

    testWidgets('item without a name uses the fallback "Item 3"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapPanel(
          FanOutChildrenPanel(
            nodeStatus: HiveNodeStatus.running,
            progress: const FanOutProgress(
              items: <FanOutItem>[
                FanOutItem(
                  index: 2,
                  name: '',
                  status: RunStatus.running,
                  runId: 'run-child-3',
                ),
              ],
            ),
            isLoading: false,
            loadFailed: false,
            failureMessage: null,
            onOpenRun: (_) {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets(
      'loading shows a spinner; error shows the banner and Retry calls onRetry',
      (tester) async {
        var retried = 0;
        await tester.pumpWidget(
          _wrapPanel(
            FanOutChildrenPanel(
              nodeStatus: HiveNodeStatus.running,
              progress: null,
              isLoading: true,
              loadFailed: false,
              failureMessage: null,
              onOpenRun: (_) {},
              onRetry: () => retried++,
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('fan_out_loading')), findsOneWidget);

        await tester.pumpWidget(
          _wrapPanel(
            FanOutChildrenPanel(
              nodeStatus: HiveNodeStatus.running,
              progress: null,
              isLoading: false,
              loadFailed: true,
              failureMessage: null,
              onOpenRun: (_) {},
              onRetry: () => retried++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('fan_out_load_error')), findsOneWidget);
        expect(find.text('Could not load child runs.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('fan_out_retry_button')));
        await tester.pumpAndSettle();
        expect(retried, 1);
      },
    );
  });

  group('RunDetailPage fan-out integration', () {
    testWidgets('a run without a fan-out node never lists children', (
      tester,
    ) async {
      final repo = _FanOutRunRepository(
        parentRun: _parentRun(includeFanOut: false),
      );
      await _pumpPage(tester, repo);

      expect(repo.listRunsCalls, 0);
    });

    testWidgets('canvas card shows the progress line', (tester) async {
      final repo = _FanOutRunRepository(parentRun: _parentRun())
        ..childSummaries.addAll(<RunSummary>[
          _childSummary(id: 'c0', status: RunStatus.succeeded),
          _childSummary(id: 'c1'),
        ])
        ..childRuns['c0'] = _childRun(
          id: 'c0',
          index: 0,
          status: RunStatus.succeeded,
        )
        ..childRuns['c1'] = _childRun(id: 'c1', index: 1);
      await _pumpPage(tester, repo);

      expect(
        find.byKey(const Key('run_graph_node_progress_fan')),
        findsOneWidget,
      );
      expect(find.text('1/2 done'), findsOneWidget);
    });

    testWidgets('canvas card shows no overflow with a paused child', (
      tester,
    ) async {
      final repo = _FanOutRunRepository(parentRun: _parentRun())
        ..childSummaries.add(_childSummary(id: 'c0', status: RunStatus.paused))
        ..childRuns['c0'] = _childRun(
          id: 'c0',
          index: 0,
          status: RunStatus.paused,
        );
      await _pumpPage(tester, repo);

      expect(tester.takeException(), isNull);
      final nodeSemantics = tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byKey(const Key('run_graph_node_fan')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .label;
      expect(nodeSemantics, contains('1 child needs you'));
    });

    testWidgets(
      'selecting the fan-out node shows the child panel instead of the log '
      'viewer',
      (tester) async {
        final repo = _FanOutRunRepository(parentRun: _parentRun())
          ..childSummaries.add(_childSummary(id: 'c0'))
          ..childRuns['c0'] = _childRun(id: 'c0', index: 0, childName: 'Alpha');
        await _pumpPage(tester, repo);

        await tester.tap(find.byKey(const Key('run_graph_node_fan')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('fan_out_progress_text')), findsOneWidget);
        expect(find.text('Alpha'), findsOneWidget);
      },
    );

    testWidgets('tapping a child in the panel navigates to the child run', (
      tester,
    ) async {
      final navigated = <String>[];
      final repo = _FanOutRunRepository(parentRun: _parentRun())
        ..childSummaries.add(_childSummary(id: 'c0'))
        ..childRuns['c0'] = _childRun(id: 'c0', index: 0, childName: 'Alpha');
      await _pumpPage(tester, repo, navigated: navigated);

      await tester.tap(find.byKey(const Key('run_graph_node_fan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fan_out_child_0')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/runs/c0']);
    });

    testWidgets('deleted child from the checkpoint output', (tester) async {
      final repo = _FanOutRunRepository(
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
                'data': <String, Object?>{
                  'total': 1,
                  'children': <Object?>[
                    <String, Object?>{
                      'index': 0,
                      'name': 'Gone',
                      'status': 'succeeded',
                      'runId': 'r9',
                    },
                  ],
                },
              },
            },
            createdAt: _baseTime,
          ),
        ],
      );
      await _pumpPage(tester, repo);

      await tester.tap(find.byKey(const Key('run_graph_node_fan')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fan_out_child_deleted_0')), findsOneWidget);
    });

    testWidgets('retry replaces the previous child in the count', (
      tester,
    ) async {
      final repo = _FanOutRunRepository(parentRun: _parentRun())
        ..childSummaries.addAll(<RunSummary>[
          _childSummary(id: 'c-old', status: RunStatus.failed),
          _childSummary(
            id: 'c-new',
            status: RunStatus.succeeded,
            startedAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
        ])
        ..childRuns['c-old'] = _childRun(
          id: 'c-old',
          index: 0,
          status: RunStatus.failed,
        )
        ..childRuns['c-new'] = _childRun(
          id: 'c-new',
          index: 0,
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 11, 21, 10, 1),
        );
      await _pumpPage(tester, repo);

      expect(find.text('1/1 done'), findsOneWidget);
    });
  });
}
