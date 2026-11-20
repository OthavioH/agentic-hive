import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  group('WsErrorPayload', () {
    test('round-trips through JSON with replyTo', () {
      const error = WsErrorPayload(
        code: WsErrorCode.unknownMessageType,
        message: 'Unknown type "x".',
        replyTo: 'msg-9',
      );

      final decoded = WsErrorPayload.fromJson(_overTheWire(error.toJson()));

      expect(decoded.code, 'unknown_message_type');
      expect(decoded.message, 'Unknown type "x".');
      expect(decoded.replyTo, 'msg-9');
    });

    test('omits replyTo from JSON when it is null', () {
      const error = WsErrorPayload(
        code: WsErrorCode.invalidMessage,
        message: 'Bad frame.',
      );

      expect(error.toJson(), {
        'code': 'invalid_message',
        'message': 'Bad frame.',
      });
      expect(
        WsErrorPayload.fromJson(_overTheWire(error.toJson())).replyTo,
        isNull,
      );
    });

    test('throws a FormatException naming "code" when it is missing', () {
      expect(
        () => WsErrorPayload.fromJson({'message': 'm'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"code"'),
          ),
        ),
      );
    });
  });
}
