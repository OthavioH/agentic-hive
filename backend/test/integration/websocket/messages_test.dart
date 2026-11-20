import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/ws_harness.dart';

void main() {
  late TestBackend server;
  late WsTestClient client;

  setUp(() async {
    server = await TestBackend.start();
    client = await server.connect();
    expect((await client.next()).type, WsMessageType.serverHello);
  });

  tearDown(() => server.dispose());

  /// Proves the connection is still open and served: an unknown type gets
  /// its own `unknown_message_type` reply.
  Future<void> expectStillServed(String probeId) async {
    client.sendEnvelope(WsEnvelope(type: 'probe', id: probeId));
    final reply = errorPayloadOf(await client.next());
    expect(reply.code, WsErrorCode.unknownMessageType);
    expect(reply.replyTo, probeId);
    expect(client.isClosed, isFalse);
  }

  test('a non-JSON text frame gets invalid_message and the connection '
      'stays open', () async {
    client.sendText('this is not json');

    final error = await client.next();

    expect(error.type, WsMessageType.error);
    expect(error.id, isNotEmpty);
    final payload = errorPayloadOf(error);
    expect(payload.code, WsErrorCode.invalidMessage);
    expect(payload.replyTo, isNull);
    await expectStillServed('after-not-json');
  });

  test('a binary frame gets invalid_message', () async {
    client.sendBinary([0x7b, 0x7d, 0x00, 0xff]);

    final payload = errorPayloadOf(await client.next());

    expect(payload.code, WsErrorCode.invalidMessage);
    expect(payload.replyTo, isNull);
    await expectStillServed('after-binary');
  });

  for (final (description, frame) in [
    ('a JSON array', '[1, 2]'),
    ('an object without id', '{"type": "x"}'),
    ('a non-string type', '{"type": 1, "id": "a"}'),
    ('a non-object payload', '{"type": "x", "id": "a", "payload": []}'),
  ]) {
    test('$description gets invalid_message', () async {
      client.sendText(frame);

      final payload = errorPayloadOf(await client.next());

      expect(payload.code, WsErrorCode.invalidMessage);
      await expectStillServed('after-malformed');
    });
  }

  test(
    'an unknown type gets unknown_message_type pointing at its id',
    () async {
      client.sendEnvelope(
        const WsEnvelope(
          type: 'does.not.exist',
          id: 'msg-42',
          payload: {'a': 1},
        ),
      );

      final error = await client.next();

      expect(error.type, WsMessageType.error);
      expect(error.id, isNot('msg-42'));
      final payload = errorPayloadOf(error);
      expect(payload.code, WsErrorCode.unknownMessageType);
      expect(payload.replyTo, 'msg-42');
      expect(payload.message, contains('does.not.exist'));
    },
  );

  test('replies keep the order of the requests', () async {
    final ids = [for (var i = 0; i < 20; i++) 'ordered-$i'];
    for (final id in ids) {
      client.sendEnvelope(WsEnvelope(type: 'nope', id: id));
    }

    final replies = [
      for (var i = 0; i < ids.length; i++)
        errorPayloadOf(await client.next()).replyTo,
    ];

    expect(replies, ids);
  });
}
