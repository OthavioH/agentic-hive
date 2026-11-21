import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('F10 WebSocket payloads', () {
    test('WsMessageType exposes run message constants', () {
      expect(WsMessageType.runSubscribe, 'run.subscribe');
      expect(WsMessageType.runUnsubscribe, 'run.unsubscribe');
      expect(WsMessageType.runEvent, 'run.event');
      expect(WsMessageType.runOutput, 'run.output');
    });

    test('RunSubscribePayload and RunUnsubscribePayload round-trip', () {
      const sub = RunSubscribePayload(runId: 'run-1');
      expect(RunSubscribePayload.fromJson(sub.toJson()), sub);

      const unsub = RunUnsubscribePayload(runId: 'run-1');
      expect(RunUnsubscribePayload.fromJson(unsub.toJson()), unsub);
    });

    test('RunEventPayload round-trips through JSON', () {
      final payload = RunEventPayload(
        event: RunEvent(
          id: 'ev-1',
          runId: 'run-1',
          sequence: 1,
          type: RunEventType.runCancelling,
          payload: const {'from': 'running'},
          createdAt: DateTime.utc(2026, 11, 20, 12),
        ),
      );
      expect(RunEventPayload.fromJson(payload.toJson()), payload);
    });

    test('RunOutputPayload round-trips through JSON', () {
      final payload = RunOutputPayload(
        runId: 'run-1',
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stderr,
        chunk: 'error line',
        timestamp: DateTime.utc(2026, 11, 20, 12, 0, 5),
        offset: 7,
      );
      final json = payload.toJson();
      expect(json['stream'], 'stderr');
      expect(json['offset'], 7);
      expect(RunOutputPayload.fromJson(json), payload);
    });
  });
}
