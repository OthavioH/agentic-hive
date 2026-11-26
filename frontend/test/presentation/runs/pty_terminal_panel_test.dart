import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/pty_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/run_output_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_run_repository.dart';

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

final class _RecordingPtyRepository implements PtyRepository {
  final List<({String runId, String nodeId, int attempt})> subscriptions =
      <({String runId, String nodeId, int attempt})>[];
  final List<({String runId, String nodeId, int attempt})> unsubscriptions =
      <({String runId, String nodeId, int attempt})>[];
  final List<List<int>> inputs = <List<int>>[];
  final List<(int cols, int rows)> resizes = <(int, int)>[];

  @override
  Future<Result<void>> subscribe({
    required String runId,
    required String nodeId,
    required int attempt,
  }) async {
    subscriptions.add((runId: runId, nodeId: nodeId, attempt: attempt));
    return const Success(null);
  }

  @override
  Future<Result<void>> unsubscribe({
    required String runId,
    required String nodeId,
    required int attempt,
  }) async {
    unsubscriptions.add((runId: runId, nodeId: nodeId, attempt: attempt));
    return const Success(null);
  }

  @override
  Future<Result<void>> sendInput({
    required String runId,
    required String nodeId,
    required int attempt,
    required List<int> bytes,
  }) async {
    inputs.add(bytes);
    return const Success(null);
  }

  @override
  Future<Result<void>> resize({
    required String runId,
    required String nodeId,
    required int attempt,
    required int cols,
    required int rows,
  }) async {
    resizes.add((cols, rows));
    return const Success(null);
  }
}

const int _debounceSettleMs = 100;

Run _buildTerminalRun({required RunStatus status, required DateTime now}) {
  return Run(
    id: 'run-1',
    workflowId: 'wf-1',
    workflowName: 'PTY Workflow',
    workflowDefinition: Workflow(
      id: 'wf-1',
      name: 'PTY Workflow',
      nodes: <WorkflowNode>[
        WorkflowNode(
          id: 'term-1',
          type: NodeTypeId.terminal,
          label: 'Interactive Shell',
          config: const TerminalHarnessNodeConfig(command: 'bash').toJson(),
          position: const WorkflowPosition(x: 0, y: 0),
        ),
      ],
      edges: const <WorkflowEdge>[],
      entryNodeId: 'term-1',
      createdAt: now,
      updatedAt: now,
    ),
    workspaceRoot: '/tmp/repo',
    status: status,
    startedAt: now,
  );
}

RunDetailState _detailStateFor({
  required Run run,
  required HiveNodeStatus nodeStatus,
}) {
  return RunDetailState(
    run: run,
    events: const <RunEvent>[],
    checkpoints: const <Checkpoint>[],
    nodeStatuses: <String, HiveNodeStatus>{'term-1': nodeStatus},
    activeNodeId: nodeStatus == HiveNodeStatus.running ? 'term-1' : null,
    inspectedNodeId: 'term-1',
    availableAttempts: const <int>[1],
    selectedAttempt: 1,
  );
}

void main() {
  testWidgets(
    'embeds HiveTerminalView in Watch mode, toggles Take over/Release, and locks to Ended when node completes',
    (tester) async {
      tester.view.physicalSize = const Size(960, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime.utc(2026, 11, 21, 5);
      final run = _buildTerminalRun(status: RunStatus.running, now: now);
      final session = _FakeWsSession();
      final ptyRepo = _RecordingPtyRepository();
      final runRepo = FakeRunRepository();

      Future<void> pumpWithStatus(HiveNodeStatus status) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              runRepositoryProvider.overrideWithValue(runRepo),
              ptyRepositoryProvider.overrideWithValue(ptyRepo),
              backendWebSocketSessionProvider.overrideWithValue(session),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: HiveTheme.dark(),
              home: Scaffold(
                body: SizedBox.fromSize(
                  size: const Size(640, 480),
                  child: RunOutputPanel(
                    runId: 'run-1',
                    detailState: _detailStateFor(run: run, nodeStatus: status),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await pumpWithStatus(HiveNodeStatus.running);
      await tester.pump();
      // Let the 80 ms resize debounce timer settle cleanly.
      await tester.pump(const Duration(milliseconds: _debounceSettleMs));

      expect(find.byType(HiveTerminalView), findsOneWidget);
      expect(find.text('Watching (read-only)'), findsOneWidget);
      expect(find.text('Watch'), findsOneWidget);
      expect(find.text('Take over'), findsOneWidget);
      expect(ptyRepo.subscriptions, [
        (runId: 'run-1', nodeId: 'term-1', attempt: 1),
      ]);
      expect(ptyRepo.resizes, isNotEmpty);

      // Stream scrollback output into the terminal.
      session.emit(
        WsEnvelope(
          id: 'out-1',
          type: WsMessageType.ptyOutput,
          payload: PtyOutputPayload(
            runId: 'run-1',
            nodeId: 'term-1',
            attempt: 1,
            data: base64Encode(utf8.encode('prompt> ')),
            timestamp: now,
            isSnapshot: true,
          ).toJson(),
        ),
      );
      await tester.pump();

      // In Watch mode, typing does not send pty.input.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      expect(ptyRepo.inputs, isEmpty);

      // Take over enables input and focuses the terminal.
      await tester.tap(find.byKey(const Key('run_terminal_takeover_button')));
      await tester.pump();

      expect(find.text('You have control'), findsOneWidget);
      expect(find.text('Interactive'), findsOneWidget);
      expect(find.text('Release'), findsOneWidget);
      expect(
        tester
            .widget<HiveTerminalView>(find.byType(HiveTerminalView))
            .focusNode!
            .hasFocus,
        isTrue,
      );

      tester.testTextInput.enterText('a');
      await tester.pump();
      expect(ptyRepo.inputs, hasLength(1));
      expect(utf8.decode(ptyRepo.inputs.single), 'a');

      // Release returns to Watch mode and unfocuses the terminal.
      await tester.tap(find.byKey(const Key('run_terminal_takeover_button')));
      await tester.pump();
      expect(find.text('Watching (read-only)'), findsOneWidget);
      expect(find.text('Take over'), findsOneWidget);
      expect(
        tester
            .widget<HiveTerminalView>(find.byType(HiveTerminalView))
            .focusNode!
            .hasFocus,
        isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(ptyRepo.inputs, hasLength(1));

      // Node completes -> locks to Ended and preserves output.
      await pumpWithStatus(HiveNodeStatus.succeeded);
      await tester.pump();
      await tester.pump();

      expect(find.byType(HiveTerminalView), findsOneWidget);
      expect(find.text('Session ended'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(
        find.byKey(const Key('run_terminal_takeover_button')),
        findsNothing,
      );

      final terminalView = tester.widget<HiveTerminalView>(
        find.byType(HiveTerminalView),
      );
      expect(terminalView.controller.plainText, contains('prompt>'));
      expect(
        find.byKey(const Key('run_terminal_ended_empty_note')),
        findsNothing,
      );

      await session.close();
    },
  );

  testWidgets(
    'fresh open of ended session shows Ended state with empty-terminal note '
    'and does not resubscribe',
    (tester) async {
      tester.view.physicalSize = const Size(960, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime.utc(2026, 11, 21, 5);
      final run = _buildTerminalRun(status: RunStatus.running, now: now);
      final session = _FakeWsSession();
      final ptyRepo = _RecordingPtyRepository();
      final runRepo = FakeRunRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runRepo),
            ptyRepositoryProvider.overrideWithValue(ptyRepo),
            backendWebSocketSessionProvider.overrideWithValue(session),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: HiveTheme.dark(),
            home: Scaffold(
              body: SizedBox.fromSize(
                size: const Size(640, 480),
                child: RunOutputPanel(
                  runId: 'run-1',
                  detailState: _detailStateFor(
                    run: run,
                    nodeStatus: HiveNodeStatus.running,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: _debounceSettleMs));

      expect(ptyRepo.subscriptions, hasLength(1));

      session.emit(
        WsEnvelope(
          id: 'err-1',
          type: WsMessageType.error,
          payload: const WsErrorPayload(
            code: WsErrorCode.ptySessionNotActive,
            message: 'PTY session is not active or has already ended.',
            replyTo: 'pty-sub-1',
          ).toJson(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(HiveTerminalView), findsOneWidget);
      expect(find.text('Session ended'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(
        find.byKey(const Key('run_terminal_takeover_button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('run_terminal_ended_empty_note')),
        findsOneWidget,
      );
      expect(find.textContaining('Output tab'), findsOneWidget);
      expect(ptyRepo.subscriptions, hasLength(1));

      await session.close();
    },
  );

  testWidgets(
    'reconnect to ended session keeps rendered output, switches to Ended, '
    'and omits empty-terminal note',
    (tester) async {
      tester.view.physicalSize = const Size(960, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime.utc(2026, 11, 21, 5);
      final run = _buildTerminalRun(status: RunStatus.running, now: now);
      final session1 = _FakeWsSession();
      final session2 = _FakeWsSession();
      final sessionController =
          StreamController<BackendWebSocketSession?>.broadcast();
      BackendWebSocketSession? currentSession = session1;
      final ptyRepo = _RecordingPtyRepository();
      final runRepo = FakeRunRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runRepo),
            ptyRepositoryProvider.overrideWithValue(ptyRepo),
            backendWebSocketSessionProvider.overrideWith((ref) {
              final sub = sessionController.stream.listen((next) {
                currentSession = next;
                ref.invalidateSelf();
              });
              ref.onDispose(sub.cancel);
              return currentSession;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: HiveTheme.dark(),
            home: Scaffold(
              body: SizedBox.fromSize(
                size: const Size(640, 480),
                child: RunOutputPanel(
                  runId: 'run-1',
                  detailState: _detailStateFor(
                    run: run,
                    nodeStatus: HiveNodeStatus.running,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: _debounceSettleMs));

      session1.emit(
        WsEnvelope(
          id: 'out-1',
          type: WsMessageType.ptyOutput,
          payload: PtyOutputPayload(
            runId: 'run-1',
            nodeId: 'term-1',
            attempt: 1,
            data: base64Encode(utf8.encode('preserved-output')),
            timestamp: now,
            isSnapshot: true,
          ).toJson(),
        ),
      );
      await tester.pump();

      sessionController.add(session2);
      await tester.pump();
      await tester.pump();
      expect(ptyRepo.subscriptions, hasLength(2));

      session2.emit(
        WsEnvelope(
          id: 'err-1',
          type: WsMessageType.error,
          payload: const WsErrorPayload(
            code: WsErrorCode.ptySessionNotActive,
            message: 'PTY session is not active or has already ended.',
            replyTo: 'pty-sub-2',
          ).toJson(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Session ended'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(
        find.byKey(const Key('run_terminal_ended_empty_note')),
        findsNothing,
      );
      final terminalView = tester.widget<HiveTerminalView>(
        find.byType(HiveTerminalView),
      );
      expect(terminalView.controller.plainText, contains('preserved-output'));

      await sessionController.close();
      await session1.close();
      await session2.close();
    },
  );
}
