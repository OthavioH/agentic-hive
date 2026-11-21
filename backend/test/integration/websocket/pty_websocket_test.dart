import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_backend/src/domain/nodes/pty_session.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

import 'support/ws_harness.dart';

final class _RecordingPtyHandle implements PtySessionHandle {
  new(this.key, this._registry);

  @override
  final PtySessionKey key;
  final PtySessionRegistry _registry;

  @override
  bool isActive = true;

  final List<String> receivedInputs = <String>[];
  final List<(int, int)> receivedResizes = <(int, int)>[];

  @override
  Future<void> writeInput(List<int> bytes) async {
    final text = utf8.decode(bytes);
    receivedInputs.add(text);
    _registry.appendOutput(key, utf8.encode('echo:$text'));
  }

  @override
  Future<void> resize(int cols, int rows) async {
    receivedResizes.add((cols, rows));
  }

  @override
  Future<void> terminate() async {
    isActive = false;
  }
}

void main() {
  group('WebSocket PTY streaming, scrollback, input & resize', () {
    late Directory dir;
    late Backend backend;
    late GetIt container;
    late PtySessionRegistry ptyRegistry;
    final clients = <WsTestClient>[];

    setUp(() async {
      dir = await createShortTempDir();
      container = GetIt.asNewInstance();
      backend = await Backend.start(
        config: AppConfig(mode: RuntimeMode.development, dataDir: dir.path),
        di: container,
        consoleOut: IOSink(_NullConsumer()),
      );
      ptyRegistry = container<PtySessionRegistry>();
    });

    tearDown(() async {
      for (final client in clients) {
        await client.close();
      }
      clients.clear();
      await backend.stop();
      await deleteDir(dir);
    });

    Future<WsTestClient> connectClient() async {
      final client = await WsTestClient.connect(backend.socketPath);
      clients.add(client);
      expect((await client.next()).type, WsMessageType.serverHello);
      return client;
    }

    test('pty.subscribe replays scrollback, streams pty.output, forwards '
        'pty.input & pty.resize, and pty.unsubscribe stops delivery', () async {
      const key = (runId: 'run-ws-1', nodeId: 'term-1', attempt: 1);
      final handle = _RecordingPtyHandle(key, ptyRegistry);
      ptyRegistry
        ..registerSession(handle)
        ..appendOutput(key, utf8.encode('prior-scrollback\r\n'));

      // Wait for coalescer to flush prior output into ring buffer + stream.
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final client = await connectClient();
      client.sendEnvelope(
        WsEnvelope(
          type: WsMessageType.ptySubscribe,
          id: 'sub-1',
          payload: const PtySubscribePayload(
            runId: 'run-ws-1',
            nodeId: 'term-1',
          ).toJson(),
        ),
      );

      final snapshotEnv = await client.next();
      expect(snapshotEnv.type, WsMessageType.ptyOutput);
      final snapshotPayload = PtyOutputPayload.fromJson(snapshotEnv.payload);
      expect(snapshotPayload.isSnapshot, isTrue);
      expect(
        utf8.decode(base64Decode(snapshotPayload.data)),
        'prior-scrollback\r\n',
      );

      client
        ..sendEnvelope(
          WsEnvelope(
            type: WsMessageType.ptyResize,
            id: 'res-1',
            payload: const PtyResizePayload(
              runId: 'run-ws-1',
              nodeId: 'term-1',
              attempt: 1,
              cols: 140,
              rows: 42,
            ).toJson(),
          ),
        )
        ..sendEnvelope(
          WsEnvelope(
            type: WsMessageType.ptyInput,
            id: 'in-1',
            payload: PtyInputPayload(
              runId: 'run-ws-1',
              nodeId: 'term-1',
              attempt: 1,
              data: base64Encode(utf8.encode('hi\r')),
            ).toJson(),
          ),
        );

      final liveEnv = await client.next();
      expect(liveEnv.type, WsMessageType.ptyOutput);
      final livePayload = PtyOutputPayload.fromJson(liveEnv.payload);
      expect(livePayload.isSnapshot, isFalse);
      expect(utf8.decode(base64Decode(livePayload.data)), 'echo:hi\r');
      expect(handle.receivedInputs, ['hi\r']);
      expect(handle.receivedResizes, [(140, 42)]);

      client.sendEnvelope(
        WsEnvelope(
          type: WsMessageType.ptyUnsubscribe,
          id: 'unsub-1',
          payload: const PtyUnsubscribePayload(
            runId: 'run-ws-1',
            nodeId: 'term-1',
          ).toJson(),
        ),
      );

      // Give server a moment to process unsubscribe, then append more output.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      ptyRegistry.appendOutput(key, utf8.encode('after-unsub'));

      // Next message should NOT arrive; sending input after session ends
      // produces ptySessionNotActive error.
      await ptyRegistry.unregisterSession(key);
      client.sendEnvelope(
        WsEnvelope(
          type: WsMessageType.ptyInput,
          id: 'in-2',
          payload: PtyInputPayload(
            runId: 'run-ws-1',
            nodeId: 'term-1',
            attempt: 1,
            data: base64Encode(utf8.encode('late')),
          ).toJson(),
        ),
      );

      final errEnv = await client.next();
      expect(errEnv.type, WsMessageType.error);
      final errPayload = WsErrorPayload.fromJson(errEnv.payload);
      expect(errPayload.code, WsErrorCode.ptySessionNotActive);
      expect(errPayload.replyTo, 'in-2');
    });
  });
}

final class _NullConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<void> close() async {}
}
