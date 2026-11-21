import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/pty_repository.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/pty_terminal_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWsSession implements BackendWebSocketSession {
  final StreamController<WsEnvelope> _messages =
      StreamController<WsEnvelope>.broadcast();
  final Completer<void> _done = Completer<void>();
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
  Future<Result<void>> send(WsEnvelope envelope) async => const Success(null);

  void emit(WsEnvelope envelope) => _messages.add(envelope);

  @override
  Future<void> close([int? code, String? reason]) async {
    _closed = true;
    if (!_done.isCompleted) _done.complete();
    await _messages.close();
  }
}

final class _RecordingPtyRepository implements PtyRepository {
  final List<({String runId, String nodeId, int attempt})> subscriptions =
      <({String runId, String nodeId, int attempt})>[];
  final List<({String runId, String nodeId, int attempt})> unsubscriptions =
      <({String runId, String nodeId, int attempt})>[];
  final List<({String runId, String nodeId, int attempt, List<int> bytes})>
  inputs = <({String runId, String nodeId, int attempt, List<int> bytes})>[];
  final List<({String runId, String nodeId, int attempt, int cols, int rows})>
  resizes =
      <({String runId, String nodeId, int attempt, int cols, int rows})>[];

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
    inputs.add((runId: runId, nodeId: nodeId, attempt: attempt, bytes: bytes));
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
    resizes.add((
      runId: runId,
      nodeId: nodeId,
      attempt: attempt,
      cols: cols,
      rows: rows,
    ));
    return const Success(null);
  }
}

const int _debounceWaitMs = 120;

WsEnvelope _ptyOutputEnvelope({
  required String runId,
  required String nodeId,
  required int attempt,
  required String text,
  bool isSnapshot = false,
}) {
  return WsEnvelope(
    id: 'out-1',
    type: WsMessageType.ptyOutput,
    payload: PtyOutputPayload(
      runId: runId,
      nodeId: nodeId,
      attempt: attempt,
      data: base64Encode(utf8.encode(text)),
      timestamp: DateTime.utc(2026, 11, 21, 5),
      isSnapshot: isSnapshot,
    ).toJson(),
  );
}

void main() {
  test(
    'subscribes on open, starts in Watch mode, and unsubscribes on dispose',
    () async {
      final session = _FakeWsSession();
      final repo = _RecordingPtyRepository();

      final container = ProviderContainer.test(
        overrides: [
          ptyRepositoryProvider.overrideWithValue(repo),
          backendWebSocketSessionProvider.overrideWithValue(session),
        ],
      );

      final provider = ptyTerminalControllerProvider('run-1', 'node-1', 1);
      final sub = container.listen(provider, (_, _) {});
      final state = sub.read();

      expect(state.mode, HiveTerminalMode.watch);
      expect(repo.subscriptions, [
        (runId: 'run-1', nodeId: 'node-1', attempt: 1),
      ]);
      expect(repo.unsubscriptions, isEmpty);

      sub.close();
      container.dispose();
      await session.close();

      expect(repo.unsubscriptions, [
        (runId: 'run-1', nodeId: 'node-1', attempt: 1),
      ]);
    },
  );

  test(
    'decodes matching pty.output frames and ignores other targets',
    () async {
      final session = _FakeWsSession();
      final repo = _RecordingPtyRepository();

      final container = ProviderContainer.test(
        overrides: [
          ptyRepositoryProvider.overrideWithValue(repo),
          backendWebSocketSessionProvider.overrideWithValue(session),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await session.close();
      });

      final provider = ptyTerminalControllerProvider('run-1', 'node-1', 2);
      final sub = container.listen(provider, (_, _) {});

      session
        ..emit(
          _ptyOutputEnvelope(
            runId: 'run-1',
            nodeId: 'node-1',
            attempt: 2,
            text: 'scrollback\r\n',
            isSnapshot: true,
          ),
        )
        ..emit(
          _ptyOutputEnvelope(
            runId: 'run-1',
            nodeId: 'node-1',
            attempt: 1,
            text: 'wrong-attempt',
          ),
        )
        ..emit(
          _ptyOutputEnvelope(
            runId: 'run-1',
            nodeId: 'other-node',
            attempt: 2,
            text: 'wrong-node',
          ),
        )
        ..emit(
          _ptyOutputEnvelope(
            runId: 'run-1',
            nodeId: 'node-1',
            attempt: 2,
            text: 'live-line',
          ),
        );
      await pumpEventQueue();

      final text = sub.read().terminalController.plainText;
      expect(text, contains('scrollback'));
      expect(text, contains('live-line'));
      expect(text, isNot(contains('wrong-attempt')));
      expect(text, isNot(contains('wrong-node')));
    },
  );

  test('gates pty.input on Interactive mode and locks to Ended', () async {
    final session = _FakeWsSession();
    final repo = _RecordingPtyRepository();

    final container = ProviderContainer.test(
      overrides: [
        ptyRepositoryProvider.overrideWithValue(repo),
        backendWebSocketSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await session.close();
    });

    final provider = ptyTerminalControllerProvider('run-1', 'node-1', 1);
    final sub = container.listen(provider, (_, _) {});
    final notifier = container.read(provider.notifier);

    session.emit(
      _ptyOutputEnvelope(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        text: 'final output',
      ),
    );
    await pumpEventQueue();

    // Watch mode: input is ignored.
    notifier.sendInput(Uint8List.fromList(utf8.encode('ignored')));
    expect(repo.inputs, isEmpty);

    // Take over -> Interactive mode: input is forwarded.
    notifier.takeOver();
    expect(sub.read().mode, HiveTerminalMode.interactive);
    notifier.sendInput(Uint8List.fromList(utf8.encode('ls\n')));
    expect(repo.inputs, hasLength(1));
    expect(utf8.decode(repo.inputs.single.bytes), 'ls\n');

    // Release -> Watch mode: input is blocked again.
    notifier.release();
    expect(sub.read().mode, HiveTerminalMode.watch);
    notifier.sendInput(Uint8List.fromList(utf8.encode('blocked')));
    expect(repo.inputs, hasLength(1));

    // Take over then markEnded -> Ended mode: cannot take over, input blocked,
    // final output preserved.
    notifier
      ..takeOver()
      ..markEnded();
    expect(sub.read().mode, HiveTerminalMode.ended);

    notifier.takeOver();
    expect(sub.read().mode, HiveTerminalMode.ended);
    notifier.sendInput(Uint8List.fromList(utf8.encode('after-end')));
    expect(repo.inputs, hasLength(1));
    expect(sub.read().terminalController.plainText, contains('final output'));
  });

  test(
    'debounces pty.resize (~80 ms) and suppresses after markEnded',
    () async {
      final session = _FakeWsSession();
      final repo = _RecordingPtyRepository();

      final container = ProviderContainer.test(
        overrides: [
          ptyRepositoryProvider.overrideWithValue(repo),
          backendWebSocketSessionProvider.overrideWithValue(session),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await session.close();
      });

      final provider = ptyTerminalControllerProvider('run-1', 'node-1', 1);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier)
        ..onResize(80, 24)
        ..onResize(100, 30)
        ..onResize(120, 36);
      expect(repo.resizes, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: _debounceWaitMs));
      expect(repo.resizes, [
        (runId: 'run-1', nodeId: 'node-1', attempt: 1, cols: 120, rows: 36),
      ]);

      // Pending resize is cancelled when the session ends.
      notifier
        ..onResize(140, 40)
        ..markEnded();
      await Future<void>.delayed(const Duration(milliseconds: _debounceWaitMs));
      expect(repo.resizes, hasLength(1));
    },
  );

  test('resets terminal and resubscribes on WebSocket reconnect without '
      'duplicating output', () async {
    final session1 = _FakeWsSession();
    final session2 = _FakeWsSession();
    final repo = _RecordingPtyRepository();

    final controller = StreamController<BackendWebSocketSession?>.broadcast();
    BackendWebSocketSession? currentSession = session1;

    final container = ProviderContainer.test(
      overrides: [
        ptyRepositoryProvider.overrideWithValue(repo),
        backendWebSocketSessionProvider.overrideWith((ref) {
          final sub = controller.stream.listen((next) {
            currentSession = next;
            ref.invalidateSelf();
          });
          ref.onDispose(sub.cancel);
          return currentSession;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await controller.close();
      await session1.close();
      await session2.close();
    });

    final provider = ptyTerminalControllerProvider('run-1', 'node-1', 1);
    final sub = container.listen(provider, (_, _) {});

    session1.emit(
      _ptyOutputEnvelope(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        text: 'hello-once\r\n',
      ),
    );
    await pumpEventQueue();
    expect(sub.read().terminalController.plainText, contains('hello-once'));

    // Simulate reconnect to a new WebSocket session.
    controller.add(session2);
    await pumpEventQueue();

    expect(repo.subscriptions, hasLength(2));

    session2.emit(
      _ptyOutputEnvelope(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        text: 'hello-once\r\nreconnected-line',
        isSnapshot: true,
      ),
    );
    await pumpEventQueue();

    final text = sub.read().terminalController.plainText;
    expect('hello-once'.allMatches(text), hasLength(1));
    expect(text, contains('reconnected-line'));
  });

  test('preserves existing output on WebSocket reconnect when no snapshot '
      'arrives', () async {
    final session1 = _FakeWsSession();
    final session2 = _FakeWsSession();
    final repo = _RecordingPtyRepository();

    final controller = StreamController<BackendWebSocketSession?>.broadcast();
    BackendWebSocketSession? currentSession = session1;

    final container = ProviderContainer.test(
      overrides: [
        ptyRepositoryProvider.overrideWithValue(repo),
        backendWebSocketSessionProvider.overrideWith((ref) {
          final sub = controller.stream.listen((next) {
            currentSession = next;
            ref.invalidateSelf();
          });
          ref.onDispose(sub.cancel);
          return currentSession;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await controller.close();
      await session1.close();
      await session2.close();
    });

    final provider = ptyTerminalControllerProvider('run-1', 'node-1', 1);
    final sub = container.listen(provider, (_, _) {});

    session1.emit(
      _ptyOutputEnvelope(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        text: 'final-output-before-disconnect',
      ),
    );
    await pumpEventQueue();
    expect(
      sub.read().terminalController.plainText,
      contains('final-output-before-disconnect'),
    );

    // Reconnect (e.g. session ended while disconnected so no snapshot arrives).
    controller.add(session2);
    await pumpEventQueue();

    expect(repo.subscriptions, hasLength(2));
    expect(
      sub.read().terminalController.plainText,
      contains('final-output-before-disconnect'),
    );
  });
}
