import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('F12 PTY WebSocket payloads', () {
    test('WsMessageType exposes pty message constants', () {
      expect(WsMessageType.ptySubscribe, 'pty.subscribe');
      expect(WsMessageType.ptyUnsubscribe, 'pty.unsubscribe');
      expect(WsMessageType.ptyOutput, 'pty.output');
      expect(WsMessageType.ptyInput, 'pty.input');
      expect(WsMessageType.ptyResize, 'pty.resize');
    });

    test('PtySubscribePayload and PtyUnsubscribePayload round-trip', () {
      const sub = PtySubscribePayload(
        runId: 'run-1',
        nodeId: 'n1',
        attempt: 2,
      );
      expect(PtySubscribePayload.fromJson(sub.toJson()), sub);

      const subDefault = PtySubscribePayload(runId: 'run-1', nodeId: 'n1');
      expect(subDefault.attempt, 1);

      const unsub = PtyUnsubscribePayload(
        runId: 'run-1',
        nodeId: 'n1',
        attempt: 2,
      );
      expect(PtyUnsubscribePayload.fromJson(unsub.toJson()), unsub);
    });

    test('PtyOutputPayload round-trips through JSON', () {
      final encoded = base64Encode(utf8.encode('\x1b[32mhello\x1b[0m'));
      final payload = PtyOutputPayload(
        runId: 'run-1',
        nodeId: 'n1',
        attempt: 1,
        data: encoded,
        timestamp: DateTime.utc(2026, 11, 21, 12),
        isSnapshot: true,
      );
      final json = payload.toJson();
      expect(json['data'], encoded);
      expect(json['isSnapshot'], isTrue);
      expect(PtyOutputPayload.fromJson(json), payload);
    });

    test('PtyInputPayload round-trips through JSON', () {
      final encoded = base64Encode(utf8.encode('ls -la\r'));
      final payload = PtyInputPayload(
        runId: 'run-1',
        nodeId: 'n1',
        attempt: 1,
        data: encoded,
      );
      expect(PtyInputPayload.fromJson(payload.toJson()), payload);
    });

    test('PtyResizePayload round-trips through JSON', () {
      const payload = PtyResizePayload(
        runId: 'run-1',
        nodeId: 'n1',
        attempt: 1,
        cols: 120,
        rows: 36,
      );
      expect(PtyResizePayload.fromJson(payload.toJson()), payload);
    });
  });
}
