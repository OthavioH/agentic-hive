import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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

  void emit(WsEnvelope envelope) => _messages.add(envelope);

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!_done.isCompleted) _done.complete();
    await _messages.close();
  }
}

final class _FakeRunRepository implements RunRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async => Success(
    Run(
      id: id,
      workflowId: 'wf-1',
      workflowName: 'Release Build',
      workflowDefinition: Workflow(
        id: 'wf-1',
        name: 'Release Build',
        nodes: const <WorkflowNode>[],
        edges: const <WorkflowEdge>[],
        createdAt: now,
        updatedAt: now,
      ),
      workspaceRoot: '/projects/hive',
      status: RunStatus.failed,
      startedAt: now,
      finishedAt: DateTime.utc(2026, 11, 21, 4, 30, 15),
      errorMessage: 'Build script exited with 1',
    ),
  );

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => Success(
    RunEventsResponse(
      items: <RunEvent>[
        RunEvent(
          id: 'evt-1',
          runId: id,
          sequence: 1,
          type: RunEventType.nodeStarted,
          nodeId: 'node-build',
          createdAt: now,
          payload: const <String, Object?>{'command': 'dart test'},
        ),
      ],
      lastSequence: 1,
    ),
  );

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      Success(<Checkpoint>[
        Checkpoint(
          id: 'cp-1',
          runId: id,
          sequence: 1,
          completedNodeId: 'node-prep',
          pendingNodeIds: const <String>['node-build'],
          attemptsByEdge: const <String, int>{'edge-prep': 1},
          circuitBreakerCount: 0,
          nodeOutputs: const <String, JsonMap>{
            'node-prep': <String, Object?>{'prepared': true},
          },
          createdAt: now,
        ),
        Checkpoint(
          id: 'cp-2',
          runId: id,
          sequence: 2,
          completedNodeId: 'node-build',
          pendingNodeIds: const <String>[],
          attemptsByEdge: const <String, int>{'edge-build': 2},
          circuitBreakerCount: 1,
          nodeOutputs: const <String, JsonMap>{
            'node-build': <String, Object?>{'exitCode': 1},
          },
          createdAt: DateTime.utc(2026, 11, 21, 4, 30, 15),
        ),
      ]);

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

Widget _buildRouterHost() {
  final router = GoRouter(
    initialLocation: '/runs/run-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/runs',
        builder: (_, _) => const Scaffold(body: Text('runs-list')),
      ),
      GoRoute(
        path: '/runs/:id',
        builder: (_, state) =>
            Scaffold(body: RunDetailPage(runId: state.pathParameters['id']!)),
      ),
    ],
  );

  return MaterialApp.router(
    theme: HiveTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  testWidgets(
    'renders summary, error banner, event payload, and checkpoint inspector',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(_FakeRunRepository()),
          ],
          child: _buildRouterHost(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Release Build'), findsOneWidget);
      expect(find.text('/projects/hive'), findsWidgets);
      expect(find.text('Build script exited with 1'), findsOneWidget);

      // Event timeline: switch to Events tab and expand JSON payload
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(find.text('node.started'), findsOneWidget);
      expect(find.byKey(const Key('run_event_payload_evt-1')), findsNothing);
      await tester.tap(find.byKey(const Key('run_event_toggle_evt-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('run_event_payload_evt-1')), findsOneWidget);
      expect(find.textContaining('"command": "dart test"'), findsOneWidget);

      // Checkpoint inspector: switch to Checkpoints tab (defaults to latest
      // cp-2), then switch to cp-1.
      await tester.tap(find.text('Checkpoints'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"exitCode": 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkpoint_chip_cp-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('"prepared": true'), findsOneWidget);
      expect(find.text('node-prep'), findsOneWidget);
    },
  );

  testWidgets('live monitor updates graph node statuses, follows active node, '
      'switches attempts, and renders header controls', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.utc(2026, 11, 21, 4, 30);
    final ws = _FakeWsSession();
    addTearDown(ws.close);

    final repo = _LiveMonitorRunRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWebSocketSessionProvider.overrideWithValue(ws),
          backendWsMessagesProvider.overrideWith((ref) => ws.messages),
        ],
        child: _buildRouterHost(),
      ),
    );
    await tester.pumpAndSettle();

    // Header shows Cancel for running run, and no Resume
    expect(find.byKey(const Key('run_detail_cancel_button')), findsOneWidget);
    expect(find.byKey(const Key('run_detail_resume_button')), findsNothing);

    // Output tab starts on active node-1 with initial log line
    expect(find.byKey(const Key('run_output_following_badge')), findsOneWidget);
    expect(find.text('initial line'), findsOneWidget);

    // Live run.output appends to node-1
    ws.emit(
      WsEnvelope(
        id: 'ws-1',
        type: WsMessageType.runOutput,
        payload: RunOutputPayload(
          runId: 'run-1',
          nodeId: 'node-1',
          attempt: 1,
          stream: RunOutputStream.stdout,
          chunk: 'streamed line\n',
          timestamp: now,
        ).toJson(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('streamed line'), findsOneWidget);

    // Manual node selection pauses follow-active and loads node-2 logs
    await tester.tap(find.byKey(const Key('run_graph_node_node-2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('run_output_follow_active_button')),
      findsOneWidget,
    );
    expect(find.text('node-2 attempt 1'), findsOneWidget);

    // Click Cancel -> transitions to cancelling (disabled + loading)
    await tester.tap(find.byKey(const Key('run_detail_cancel_button')));
    await tester.pump();
    await tester.pump();
    expect(repo.cancelCalls, 1);
    final cancelBtn = tester.widget<HiveButton>(
      find.byKey(const Key('run_detail_cancel_button')),
    );
    expect(cancelBtn.onPressed, isNull);
    expect(cancelBtn.loading, isTrue);

    // Emit cancellationUncertain -> shows Retry cancel
    ws.emit(
      WsEnvelope(
        id: 'ws-2',
        type: WsMessageType.runEvent,
        payload: RunEventPayload(
          event: RunEvent(
            id: 'evt-uncertain',
            runId: 'run-1',
            sequence: 2,
            type: RunEventType.runCancellationUncertain,
            createdAt: now,
          ),
        ).toJson(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('run_detail_retry_cancel_button')),
      findsOneWidget,
    );
    final nodeSemantics = tester
        .widget<Semantics>(
          find
              .descendant(
                of: find.byKey(const Key('run_graph_node_node-1')),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties
        .label;
    expect(nodeSemantics, 'Build step (Cancellation uncertain)');
    final statusDot = tester.widget<HiveStatusDot>(
      find.byKey(const Key('run_graph_node_status_node-1')),
    );
    expect(statusDot.semanticLabel, 'Cancellation uncertain');

    // Emit runInterrupted -> shows Resume
    ws.emit(
      WsEnvelope(
        id: 'ws-3',
        type: WsMessageType.runEvent,
        payload: RunEventPayload(
          event: RunEvent(
            id: 'evt-interrupted',
            runId: 'run-1',
            sequence: 3,
            type: RunEventType.runInterrupted,
            createdAt: now,
          ),
        ).toJson(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run_detail_resume_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('run_detail_resume_button')));
    await tester.pumpAndSettle();
    expect(repo.resumeCalls, 1);
  });

  testWidgets('RunDetailPage renders collapsible run input when present', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longInput = List<String>.generate(
      8,
      (i) => 'Line ${i + 1}: verify module ${i + 1} invariants.',
    ).join('\n');
    final repo = _InputRunRepository(longInput);
    final ws = _FakeWsSession();
    addTearDown(ws.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWebSocketSessionProvider.overrideWithValue(ws),
          backendWsMessagesProvider.overrideWith((ref) => ws.messages),
        ],
        child: _buildRouterHost(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run_detail_input_card')), findsOneWidget);
    final toggle = find.byKey(const Key('run_detail_input_toggle'));
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Line 8: verify module 8 invariants.'),
      findsOneWidget,
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();
  });

  testWidgets('RunDetailPage copies full untrimmed input even when collapsed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
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

    final lines = List<String>.generate(
      8,
      (i) => 'Line ${i + 1}: verify module ${i + 1}',
    );
    final longUntrimmed = '  ${lines.join('\n')}  ';
    final repo = _InputRunRepository(longUntrimmed);
    final ws = _FakeWsSession();
    addTearDown(ws.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWebSocketSessionProvider.overrideWithValue(ws),
          backendWsMessagesProvider.overrideWith((ref) => ws.messages),
        ],
        child: _buildRouterHost(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('run_detail_input_copy')));
    await tester.pump();

    expect(copiedText, longUntrimmed);
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('RunDetailPage shows attachment-only input card without copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _InputRunRepository(
      null,
      attachments: const <RunAttachment>[
        RunAttachment(
          fileName: 'x.png',
          mimeType: 'image/png',
          sizeBytes: 1229,
        ),
      ],
      status: RunStatus.running,
    );
    final ws = _FakeWsSession();
    addTearDown(ws.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWebSocketSessionProvider.overrideWithValue(ws),
          backendWsMessagesProvider.overrideWith((ref) => ws.messages),
        ],
        child: _buildRouterHost(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run_detail_input_card')), findsOneWidget);
    expect(find.byKey(const Key('run_detail_input_copy')), findsNothing);
    expect(find.text('x.png · 1.2 KB'), findsOneWidget);
    final chip = tester.widget<HiveReadOnlyChip>(
      find.byKey(const Key('run_detail_attachment_0')),
    );
    expect(chip.removed, isFalse);
  });

  for (final endedStatus in const <RunStatus>[
    RunStatus.succeeded,
    RunStatus.failed,
    RunStatus.cancelled,
  ]) {
    testWidgets(
      'RunDetailPage marks attachment chips removed for ${endedStatus.name}',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final repo = _InputRunRepository(
          'See image',
          attachments: const <RunAttachment>[
            RunAttachment(
              fileName: 'x.png',
              mimeType: 'image/png',
              sizeBytes: 1229,
            ),
          ],
          status: endedStatus,
        );
        final ws = _FakeWsSession();
        addTearDown(ws.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              runRepositoryProvider.overrideWithValue(repo),
              backendWebSocketSessionProvider.overrideWithValue(ws),
              backendWsMessagesProvider.overrideWith((ref) => ws.messages),
            ],
            child: _buildRouterHost(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('x.png · 1.2 KB · removed'), findsOneWidget);
        final chip = tester.widget<HiveReadOnlyChip>(
          find.byKey(const Key('run_detail_attachment_0')),
        );
        expect(chip.removed, isTrue);
      },
    );
  }
}

final class _InputRunRepository extends _FakeRunRepository {
  new(this._input, {this.attachments, this.status});

  final String? _input;
  final List<RunAttachment>? attachments;
  final RunStatus? status;

  @override
  Future<Result<Run>> getRun(String id) async {
    final base = (await super.getRun(id)).valueOrNull!;
    return Success(
      base.copyWith(
        input: _input,
        attachments: attachments,
        status: status ?? base.status,
      ),
    );
  }
}

final class _LiveMonitorRunRepository extends _FakeRunRepository {
  new();

  int cancelCalls = 0;
  int resumeCalls = 0;

  @override
  Future<Result<Run>> getRun(String id) async => Success(
    Run(
      id: id,
      workflowId: 'wf-1',
      workflowName: 'Release Build',
      workflowDefinition: Workflow(
        id: 'wf-1',
        name: 'Release Build',
        nodes: const <WorkflowNode>[
          WorkflowNode(
            id: 'node-1',
            type: 'command',
            label: 'Build step',
            position: WorkflowPosition(x: 40, y: 40),
          ),
          WorkflowNode(
            id: 'node-2',
            type: 'command',
            label: 'Test step',
            position: WorkflowPosition(x: 320, y: 40),
          ),
        ],
        edges: const <WorkflowEdge>[
          WorkflowEdge(
            id: 'edge-1',
            sourceNodeId: 'node-1',
            sourceOutput: NodeOutput.onSuccess,
            targetNodeId: 'node-2',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
      workspaceRoot: '/projects/hive',
      status: RunStatus.running,
      startedAt: now,
    ),
  );

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => Success(
    RunEventsResponse(
      items: <RunEvent>[
        RunEvent(
          id: 'evt-1',
          runId: id,
          sequence: 1,
          type: RunEventType.nodeStarted,
          nodeId: 'node-1',
          createdAt: now,
        ),
      ],
      lastSequence: 1,
    ),
  );

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async => Success(
    RunNodeLogsResponse(
      runId: id,
      nodeId: nodeId,
      attempt: attempt ?? 1,
      availableAttempts: const <int>[1, 2],
      entries: <RunLogEntry>[
        RunLogEntry(
          stream: RunOutputStream.stdout,
          chunk: nodeId == 'node-1'
              ? 'initial line\n'
              : 'node-2 attempt ${attempt ?? 1}\n',
          timestamp: now,
        ),
      ],
    ),
  );

  @override
  Future<Result<Run>> cancelRun(String id) async {
    cancelCalls++;
    final run = (await getRun(id)).valueOrNull!;
    return Success(run.copyWith(status: RunStatus.cancelling));
  }

  @override
  Future<Result<Run>> resumeRun(String id) async {
    resumeCalls++;
    final run = (await getRun(id)).valueOrNull!;
    return Success(run.copyWith(status: RunStatus.running));
  }
}
