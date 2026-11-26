import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWsSession implements BackendWebSocketSession {
  final StreamController<WsEnvelope> _messages =
      StreamController<WsEnvelope>.broadcast();
  final Completer<void> _done = Completer<void>();
  final List<WsEnvelope> sent = <WsEnvelope>[];
  bool _closed = false;

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
  bool get isClosed => _closed;

  @override
  Future<Result<void>> send(WsEnvelope envelope) async {
    sent.add(envelope);
    return const Success(null);
  }

  void emit(WsEnvelope envelope) {
    _messages.add(envelope);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    _closed = true;
    if (!_done.isCompleted) _done.complete();
    await _messages.close();
  }
}

final class _FakeRunRepository implements RunRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);
  Result<Run>? runOverride;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async {
    if (runOverride != null) return runOverride!;
    return Success(
      Run(
        id: id,
        workflowId: 'wf-1',
        workflowName: 'PR Review',
        workflowDefinition: Workflow(
          id: 'wf-1',
          name: 'PR Review',
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        workspaceRoot: '/tmp/repo',
        status: RunStatus.succeeded,
        startedAt: now,
        finishedAt: DateTime.utc(2026, 11, 21, 4, 30, 10),
      ),
    );
  }

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
          type: RunEventType.runStarted,
          createdAt: now,
          payload: const <String, Object?>{'step': 'init'},
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
          completedNodeId: 'node-1',
          pendingNodeIds: const <String>['node-2'],
          attemptsByEdge: const <String, int>{'e-1': 1},
          circuitBreakerCount: 0,
          nodeOutputs: const <String, JsonMap>{
            'node-1': <String, Object?>{'status': 'ok'},
          },
          createdAt: now,
        ),
        Checkpoint(
          id: 'cp-2',
          runId: id,
          sequence: 2,
          completedNodeId: 'node-2',
          pendingNodeIds: const <String>[],
          attemptsByEdge: const <String, int>{},
          circuitBreakerCount: 0,
          nodeOutputs: const <String, JsonMap>{
            'node-2': <String, Object?>{'done': true},
          },
          createdAt: DateTime.utc(2026, 11, 21, 4, 30, 5),
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

void main() {
  group('RunDetailController', () {
    test(
      'loads run, events, checkpoints and defaults to latest checkpoint',
      () async {
        final repo = _FakeRunRepository();
        final container = ProviderContainer.test(
          overrides: [runRepositoryProvider.overrideWithValue(repo)],
        );

        final state = await container.read(
          runDetailControllerProvider('run-1').future,
        );
        expect(state.run.id, 'run-1');
        expect(state.events, hasLength(1));
        expect(state.checkpoints, hasLength(2));
        expect(state.selectedCheckpointId, 'cp-2');
        expect(state.selectedCheckpoint?.sequence, 2);
        expect(state.expandedEventIds, isEmpty);
      },
    );

    test('selectCheckpoint and toggleEventExpanded update state', () async {
      final repo = _FakeRunRepository();
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [runRepositoryProvider.overrideWithValue(repo)],
      );
      await container.read(runDetailControllerProvider('run-1').future);

      final notifier = container.read(
        runDetailControllerProvider('run-1').notifier,
      )..selectCheckpoint('cp-1');
      var current = container
          .read(runDetailControllerProvider('run-1'))
          .requireValue;
      expect(current.selectedCheckpointId, 'cp-1');

      notifier.toggleEventExpanded('evt-1');
      current = container
          .read(runDetailControllerProvider('run-1'))
          .requireValue;
      expect(current.expandedEventIds, contains('evt-1'));

      notifier.toggleEventExpanded('evt-1');
      current = container
          .read(runDetailControllerProvider('run-1'))
          .requireValue;
      expect(current.expandedEventIds, isEmpty);
    });

    test('surfaces AsyncError when getRun fails', () async {
      final repo = _FakeRunRepository()
        ..runOverride = const FailureResult(NotFoundFailure('missing'));
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [runRepositoryProvider.overrideWithValue(repo)],
      );

      final sub = container.listen(
        runDetailControllerProvider('missing'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await expectLater(
        container.read(runDetailControllerProvider('missing').future),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(sub.read().hasError, isTrue);
    });

    test('subscribes via WS, handles live events/output, follow-active, '
        'attempt, cancel and resume', () async {
      final now = DateTime.utc(2026, 11, 21, 4, 30);
      final repo = _FakeRunRepository();
      final ws = _FakeWsSession();
      addTearDown(ws.close);

      final customRepo = _LiveFakeRunRepository(now: now);
      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(customRepo),
          backendWebSocketSessionProvider.overrideWithValue(ws),
          backendWsMessagesProvider.overrideWith((ref) => ws.messages),
        ],
      );
      final sub = container.listen(
        runDetailControllerProvider('run-live'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final initial = await container.read(
        runDetailControllerProvider('run-live').future,
      );
      await Future<void>.delayed(Duration.zero);
      expect(initial.run.status, RunStatus.running);
      expect(initial.activeNodeId, 'node-1');
      expect(initial.inspectedNodeId, 'node-1');
      expect(initial.followActiveNode, isTrue);
      expect(ws.sent.any((e) => e.type == WsMessageType.runSubscribe), isTrue);

      final notifier = container.read(
        runDetailControllerProvider('run-live').notifier,
      );

      // Stream stdout chunk to node-1
      ws.emit(
        WsEnvelope(
          id: 'ws-1',
          type: WsMessageType.runOutput,
          payload: RunOutputPayload(
            runId: 'run-live',
            nodeId: 'node-1',
            attempt: 1,
            stream: RunOutputStream.stdout,
            chunk: 'building...\n',
            timestamp: now,
          ).toJson(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        notifier.logController.lines.map((l) => l.text),
        contains('building...'),
      );

      // Emit node.completed(node-1) and node.started(node-2) -> auto-follow
      // switches to node-2.
      ws
        ..emit(
          WsEnvelope(
            id: 'ws-2',
            type: WsMessageType.runEvent,
            payload: RunEventPayload(
              event: RunEvent(
                id: 'evt-2',
                runId: 'run-live',
                sequence: 2,
                type: RunEventType.nodeCompleted,
                nodeId: 'node-1',
                createdAt: now,
              ),
            ).toJson(),
          ),
        )
        ..emit(
          WsEnvelope(
            id: 'ws-3',
            type: WsMessageType.runEvent,
            payload: RunEventPayload(
              event: RunEvent(
                id: 'evt-3',
                runId: 'run-live',
                sequence: 3,
                type: RunEventType.nodeStarted,
                nodeId: 'node-2',
                createdAt: now,
              ),
            ).toJson(),
          ),
        );
      await Future<void>.delayed(Duration.zero);

      var current = container
          .read(runDetailControllerProvider('run-live'))
          .requireValue;
      expect(current.nodeStatuses['node-1'], HiveNodeStatus.succeeded);
      expect(current.nodeStatuses['node-2'], HiveNodeStatus.running);
      expect(current.activeNodeId, 'node-2');
      expect(current.inspectedNodeId, 'node-2');

      // Manual select node-1 disables followActiveNode
      await notifier.selectNode('node-1');
      current = container
          .read(runDetailControllerProvider('run-live'))
          .requireValue;
      expect(current.followActiveNode, isFalse);
      expect(current.inspectedNodeId, 'node-1');

      // Select attempt 2
      await notifier.selectAttempt(2);
      expect(customRepo.lastLogsAttempt, 2);

      // Re-enable followActiveNode switches back to node-2
      await notifier.enableFollowActive();
      current = container
          .read(runDetailControllerProvider('run-live'))
          .requireValue;
      expect(current.followActiveNode, isTrue);
      expect(current.inspectedNodeId, 'node-2');

      // Cancel transitions run
      await notifier.cancelRun();
      current = container
          .read(runDetailControllerProvider('run-live'))
          .requireValue;
      expect(current.run.status, RunStatus.cancelling);

      // Resume transitions run
      await notifier.resumeRun();
      current = container
          .read(runDetailControllerProvider('run-live'))
          .requireValue;
      expect(current.run.status, RunStatus.running);

      container.dispose();
      expect(
        ws.sent.any((e) => e.type == WsMessageType.runUnsubscribe),
        isTrue,
      );
      expect(repo.now, now);
    });

    test('buffers WS chunks during REST log load, deduplicates by offset, '
        'and switches attempt when followActiveNode is true', () async {
      final now = DateTime.utc(2026, 11, 21, 4, 30);
      final ws = _FakeWsSession();
      addTearDown(ws.close);

      final logsGate = Completer<RunNodeLogsResponse>();
      final customRepo = _LiveFakeRunRepository(now: now)
        ..onGetNodeLogs = (id, nodeId, {attempt, tail}) =>
            logsGate.future.then(Success<RunNodeLogsResponse>.new);

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(customRepo),
          backendWebSocketSessionProvider.overrideWithValue(ws),
          backendWsMessagesProvider.overrideWith((ref) => ws.messages),
        ],
      );
      final sub = container.listen(
        runDetailControllerProvider('run-race'),
        (_, _) {},
      );
      addTearDown(sub.close);

      // Wait until _load reaches getNodeLogs, then emit WS chunks while
      // the initial REST load is still in flight.
      await Future<void>.delayed(Duration.zero);
      ws
        ..emit(
          WsEnvelope(
            id: 'ws-dup-1',
            type: WsMessageType.runOutput,
            payload: RunOutputPayload(
              runId: 'run-race',
              nodeId: 'node-1',
              attempt: 1,
              stream: RunOutputStream.stdout,
              chunk: 'line-1\n',
              timestamp: now,
              offset: 1,
            ).toJson(),
          ),
        )
        ..emit(
          WsEnvelope(
            id: 'ws-new-3',
            type: WsMessageType.runOutput,
            payload: RunOutputPayload(
              runId: 'run-race',
              nodeId: 'node-1',
              attempt: 1,
              stream: RunOutputStream.stdout,
              chunk: 'line-3\n',
              timestamp: now,
              offset: 3,
            ).toJson(),
          ),
        );
      await Future<void>.delayed(Duration.zero);

      logsGate.complete(
        RunNodeLogsResponse(
          runId: 'run-race',
          nodeId: 'node-1',
          attempt: 1,
          availableAttempts: const <int>[1],
          offset: 2,
          entries: <RunLogEntry>[
            RunLogEntry(
              stream: RunOutputStream.stdout,
              chunk: 'line-1\n',
              timestamp: now,
              offset: 1,
            ),
            RunLogEntry(
              stream: RunOutputStream.stdout,
              chunk: 'line-2\n',
              timestamp: now,
              offset: 2,
            ),
          ],
        ),
      );

      final state = await container.read(
        runDetailControllerProvider('run-race').future,
      );
      expect(state.selectedAttempt, 1);

      final notifier = container.read(
        runDetailControllerProvider('run-race').notifier,
      );
      expect(notifier.logController.maxLines, RunDetailController.maxLogLines);
      expect(notifier.logController.lines.map((l) => l.text).toList(), <String>[
        'line-1',
        'line-2',
        'line-3',
      ]);

      // Newer attempt arrives while followActiveNode is true -> switches to
      // attempt 2, clears previous attempt lines, and appends new chunk.
      ws.emit(
        WsEnvelope(
          id: 'ws-attempt-2',
          type: WsMessageType.runOutput,
          payload: RunOutputPayload(
            runId: 'run-race',
            nodeId: 'node-1',
            attempt: 2,
            stream: RunOutputStream.stdout,
            chunk: 'retry-line-1\n',
            timestamp: now,
            offset: 1,
          ).toJson(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final afterRetry = container
          .read(runDetailControllerProvider('run-race'))
          .requireValue;
      expect(afterRetry.selectedAttempt, 2);
      expect(afterRetry.availableAttempts, <int>[1, 2]);
      expect(notifier.logController.lines.map((l) => l.text).toList(), <String>[
        'retry-line-1',
      ]);
    });

    test('resyncs events and logs on WS reconnect and converts '
        'cancellationUncertain to cancelling on retry cancel', () async {
      final now = DateTime.utc(2026, 11, 21, 4, 30);
      final ws1 = _FakeWsSession();
      final ws2 = _FakeWsSession();
      addTearDown(ws1.close);
      addTearDown(ws2.close);

      var eventsCalls = 0;
      var logsCalls = 0;
      final customRepo = _LiveFakeRunRepository(now: now)
        ..onGetRunEvents = (id, {afterSequence, limit}) async {
          eventsCalls++;
          if (eventsCalls == 1) {
            return Success(
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
                  RunEvent(
                    id: 'evt-2',
                    runId: id,
                    sequence: 2,
                    type: RunEventType.runCancellationUncertain,
                    createdAt: now,
                  ),
                ],
                lastSequence: 2,
              ),
            );
          }
          return Success(
            RunEventsResponse(
              items: <RunEvent>[
                RunEvent(
                  id: 'evt-3',
                  runId: id,
                  sequence: 3,
                  type: RunEventType.runCancelling,
                  createdAt: now,
                ),
              ],
              lastSequence: 3,
            ),
          );
        }
        ..onGetNodeLogs = (id, nodeId, {attempt, tail}) async {
          logsCalls++;
          if (logsCalls == 1) {
            return Success(
              RunNodeLogsResponse(
                runId: id,
                nodeId: nodeId,
                attempt: 1,
                availableAttempts: const <int>[1],
                offset: 1,
                entries: <RunLogEntry>[
                  RunLogEntry(
                    stream: RunOutputStream.stdout,
                    chunk: 'initial\n',
                    timestamp: now,
                    offset: 1,
                  ),
                ],
              ),
            );
          }
          return Success(
            RunNodeLogsResponse(
              runId: id,
              nodeId: nodeId,
              attempt: 1,
              availableAttempts: const <int>[1],
              offset: 2,
              entries: <RunLogEntry>[
                RunLogEntry(
                  stream: RunOutputStream.stdout,
                  chunk: 'initial\n',
                  timestamp: now,
                  offset: 1,
                ),
                RunLogEntry(
                  stream: RunOutputStream.stdout,
                  chunk: 'missed-while-offline\n',
                  timestamp: now,
                  offset: 2,
                ),
              ],
            ),
          );
        };

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(customRepo),
          backendWebSocketSessionProvider.overrideWithValue(ws1),
          backendWsMessagesProvider.overrideWith((ref) => ws1.messages),
        ],
      );
      final sub = container.listen(
        runDetailControllerProvider('run-reconn'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final initial = await container.read(
        runDetailControllerProvider('run-reconn').future,
      );
      expect(
        initial.nodeStatuses['node-1'],
        HiveNodeStatus.cancellationUncertain,
      );

      // Simulate WS reconnect by updating provider override to ws2.
      container.updateOverrides([
        runRepositoryProvider.overrideWithValue(customRepo),
        backendWebSocketSessionProvider.overrideWithValue(ws2),
        backendWsMessagesProvider.overrideWith((ref) => ws2.messages),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(ws2.sent.any((e) => e.type == WsMessageType.runSubscribe), isTrue);
      final reconnected = container
          .read(runDetailControllerProvider('run-reconn'))
          .requireValue;
      expect(reconnected.events.map((e) => e.id), <String>[
        'evt-1',
        'evt-2',
        'evt-3',
      ]);
      expect(reconnected.nodeStatuses['node-1'], HiveNodeStatus.cancelling);

      final notifier = container.read(
        runDetailControllerProvider('run-reconn').notifier,
      );
      expect(notifier.logController.lines.map((l) => l.text).toList(), <String>[
        'initial',
        'missed-while-offline',
      ]);
    });
  });

  group('RunDetailState.ranOnByNodeId', () {
    final now = DateTime.utc(2026, 11, 25, 12);

    RunDetailState makeState({
      required List<WorkflowNode> nodes,
      required List<RunEvent> events,
    }) {
      return RunDetailState(
        run: Run(
          id: 'run-1',
          workflowId: 'wf-1',
          workflowName: 'Test',
          workflowDefinition: Workflow(
            id: 'wf-1',
            name: 'Test',
            nodes: nodes,
            edges: const <WorkflowEdge>[],
            createdAt: now,
            updatedAt: now,
          ),
          workspacePath: '/tmp/repo',
          status: RunStatus.succeeded,
          startedAt: now,
        ),
        events: events,
        checkpoints: const <Checkpoint>[],
      );
    }

    RunEvent fallbackEvent(
      String id,
      int seq,
      String? nodeId,
      Map<String, Object?> payload,
    ) => RunEvent(
      id: id,
      runId: 'run-1',
      sequence: seq,
      type: RunEventType.nodeFallback,
      nodeId: nodeId,
      createdAt: now,
      payload: payload,
    );

    test('returns latest fallback target per node', () {
      final state = makeState(
        nodes: const <WorkflowNode>[
          WorkflowNode(
            id: 'n1',
            type: NodeTypeId.claudeCode,
            label: 'Coder',
            position: WorkflowPosition(x: 0, y: 0),
          ),
        ],
        events: <RunEvent>[
          fallbackEvent('e1', 1, 'n1', const <String, Object?>{
            'from': <String, Object?>{'harness': NodeTypeId.claudeCode},
            'to': <String, Object?>{'harness': NodeTypeId.geminiCli},
            'reason': 'rate limit',
          }),
          fallbackEvent('e2', 2, 'n1', const <String, Object?>{
            'from': <String, Object?>{'harness': NodeTypeId.geminiCli},
            'to': <String, Object?>{
              'harness': NodeTypeId.codex,
              'model': 'gpt-x',
            },
            'reason': 'rate limit',
          }),
        ],
      );

      expect(state.ranOnByNodeId, <String, FallbackEntry>{
        'n1': const FallbackEntry(harness: NodeTypeId.codex, model: 'gpt-x'),
      });
    });

    test('omits entry when target equals node own type and model', () {
      final state = makeState(
        nodes: const <WorkflowNode>[
          WorkflowNode(
            id: 'n1',
            type: NodeTypeId.claudeCode,
            label: 'Coder',
            position: WorkflowPosition(x: 0, y: 0),
            config: <String, dynamic>{'model': '  sonnet  '},
          ),
        ],
        events: <RunEvent>[
          fallbackEvent('e1', 1, 'n1', const <String, Object?>{
            'from': <String, Object?>{'harness': NodeTypeId.codex},
            'to': <String, Object?>{
              'harness': NodeTypeId.claudeCode,
              'model': 'sonnet',
            },
            'reason': 'switched',
          }),
        ],
      );

      expect(state.ranOnByNodeId, isEmpty);
    });

    test('includes entry when same harness has a different model', () {
      final state = makeState(
        nodes: const <WorkflowNode>[
          WorkflowNode(
            id: 'n1',
            type: NodeTypeId.claudeCode,
            label: 'Coder',
            position: WorkflowPosition(x: 0, y: 0),
            config: <String, dynamic>{'model': 'opus'},
          ),
        ],
        events: <RunEvent>[
          fallbackEvent('e1', 1, 'n1', const <String, Object?>{
            'from': <String, Object?>{
              'harness': NodeTypeId.claudeCode,
              'model': 'opus',
            },
            'to': <String, Object?>{
              'harness': NodeTypeId.claudeCode,
              'model': 'sonnet',
            },
            'reason': 'rate limit',
          }),
        ],
      );

      expect(state.ranOnByNodeId, <String, FallbackEntry>{
        'n1': const FallbackEntry(
          harness: NodeTypeId.claudeCode,
          model: 'sonnet',
        ),
      });
    });

    test('returns empty map when no events or payload is malformed', () {
      final state = makeState(
        nodes: const <WorkflowNode>[
          WorkflowNode(
            id: 'n1',
            type: NodeTypeId.claudeCode,
            label: 'Coder',
            position: WorkflowPosition(x: 0, y: 0),
          ),
        ],
        events: <RunEvent>[
          fallbackEvent('e1', 1, 'n1', const <String, Object?>{'to': 'bad'}),
          fallbackEvent('e2', 2, 'n1', const <String, Object?>{
            'to': <String, Object?>{'model': 'no-harness'},
          }),
          fallbackEvent('e3', 3, 'missing-node', const <String, Object?>{
            'to': <String, Object?>{'harness': NodeTypeId.codex},
          }),
        ],
      );

      expect(state.ranOnByNodeId, isEmpty);
    });
  });
}

final class _LiveFakeRunRepository extends _FakeRunRepository {
  new({required DateTime now}) : _createdAt = now;

  final DateTime _createdAt;
  int? lastLogsAttempt;
  Future<Result<RunNodeLogsResponse>> Function(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  })?
  onGetNodeLogs;
  Future<Result<RunEventsResponse>> Function(
    String id, {
    int? afterSequence,
    int? limit,
  })?
  onGetRunEvents;

  @override
  Future<Result<Run>> getRun(String id) async => Success(
    Run(
      id: id,
      workflowId: 'wf-1',
      workflowName: 'Live Pipeline',
      workflowDefinition: Workflow(
        id: 'wf-1',
        name: 'Live Pipeline',
        nodes: const <WorkflowNode>[
          WorkflowNode(
            id: 'node-1',
            type: 'command',
            label: 'Step 1',
            position: WorkflowPosition(x: 0, y: 0),
          ),
          WorkflowNode(
            id: 'node-2',
            type: 'command',
            label: 'Step 2',
            position: WorkflowPosition(x: 280, y: 0),
          ),
        ],
        edges: const <WorkflowEdge>[],
        createdAt: _createdAt,
        updatedAt: _createdAt,
      ),
      workspaceRoot: '/tmp/repo',
      status: RunStatus.running,
      startedAt: _createdAt,
    ),
  );

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) {
    final handler = onGetRunEvents;
    if (handler != null) {
      return handler(id, afterSequence: afterSequence, limit: limit);
    }
    return Future<Result<RunEventsResponse>>.value(
      Success(
        RunEventsResponse(
          items: <RunEvent>[
            RunEvent(
              id: 'evt-1',
              runId: id,
              sequence: 1,
              type: RunEventType.nodeStarted,
              nodeId: 'node-1',
              createdAt: _createdAt,
            ),
          ],
          lastSequence: 1,
        ),
      ),
    );
  }

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) {
    lastLogsAttempt = attempt;
    final handler = onGetNodeLogs;
    if (handler != null) {
      return handler(id, nodeId, attempt: attempt, tail: tail);
    }
    return Future<Result<RunNodeLogsResponse>>.value(
      Success(
        RunNodeLogsResponse(
          runId: id,
          nodeId: nodeId,
          attempt: attempt ?? 1,
          availableAttempts: const <int>[1, 2],
        ),
      ),
    );
  }

  @override
  Future<Result<Run>> cancelRun(String id) async {
    final run = (await getRun(id)).valueOrNull!;
    return Success(run.copyWith(status: RunStatus.cancelling));
  }

  @override
  Future<Result<Run>> resumeRun(String id) async {
    final run = (await getRun(id)).valueOrNull!;
    return Success(run.copyWith(status: RunStatus.running));
  }
}
