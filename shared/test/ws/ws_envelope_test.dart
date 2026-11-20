import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

Matcher _formatErrorNaming(String field) => isA<FormatException>().having(
  (e) => e.message,
  'message',
  contains('"$field"'),
);

void main() {
  group('WsEnvelope', () {
    test('round-trips through encode and decode', () {
      const envelope = WsEnvelope(
        type: WsMessageType.serverHello,
        id: 'msg-1',
        payload: {'serverVersion': '0.1.0', 'protocolVersion': 1},
      );

      final decoded = WsEnvelope.decode(envelope.encode());

      expect(decoded.type, 'server.hello');
      expect(decoded.id, 'msg-1');
      expect(decoded.payload, {'serverVersion': '0.1.0', 'protocolVersion': 1});
    });

    test('always encodes the payload, empty by default', () {
      const envelope = WsEnvelope(type: WsMessageType.error, id: 'msg-2');

      expect(envelope.toJson(), {
        'type': 'error',
        'id': 'msg-2',
        'payload': <String, Object?>{},
      });
    });

    test('treats a missing or null payload as empty', () {
      expect(WsEnvelope.decode('{"type":"t","id":"1"}').payload, isEmpty);
      expect(
        WsEnvelope.decode('{"type":"t","id":"1","payload":null}').payload,
        isEmpty,
      );
    });

    group('decode rejects an invalid frame', () {
      test('that is not JSON', () {
        expect(() => WsEnvelope.decode('not json'), throwsFormatException);
      });

      test('that is a JSON array', () {
        expect(() => WsEnvelope.decode('[1, 2]'), throwsFormatException);
      });

      test('that is a JSON string', () {
        expect(() => WsEnvelope.decode('"hello"'), throwsFormatException);
      });

      test('without a type, naming "type"', () {
        expect(
          () => WsEnvelope.decode('{"id":"1"}'),
          throwsA(_formatErrorNaming('type')),
        );
      });

      test('without an id, naming "id"', () {
        expect(
          () => WsEnvelope.decode('{"type":"t"}'),
          throwsA(_formatErrorNaming('id')),
        );
      });

      test('whose payload is not an object, naming "payload"', () {
        expect(
          () => WsEnvelope.decode('{"type":"t","id":"1","payload":[1]}'),
          throwsA(_formatErrorNaming('payload')),
        );
      });
    });

    test('fromJson accepts a decoded map', () {
      final json = jsonDecode('{"type":"t","id":"1","payload":{"a":1}}');

      final envelope = WsEnvelope.fromJson(json as Map<String, Object?>);

      expect(envelope.payload, {'a': 1});
    });
  });
}
