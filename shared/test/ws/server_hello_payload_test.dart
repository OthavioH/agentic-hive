import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('ServerHelloPayload', () {
    test('round-trips through JSON', () {
      const hello = ServerHelloPayload(
        serverVersion: '0.1.0',
        protocolVersion: wsProtocolVersion,
      );
      final wire =
          jsonDecode(jsonEncode(hello.toJson())) as Map<String, Object?>;

      final decoded = ServerHelloPayload.fromJson(wire);

      expect(decoded.serverVersion, '0.1.0');
      expect(decoded.protocolVersion, wsProtocolVersion);
    });

    test('encodes both fields', () {
      expect(
        const ServerHelloPayload(
          serverVersion: '1.2.3',
          protocolVersion: 7,
        ).toJson(),
        {'serverVersion': '1.2.3', 'protocolVersion': 7},
      );
    });

    test('throws a FormatException naming "protocolVersion" when it is not an '
        'int', () {
      expect(
        () => ServerHelloPayload.fromJson({
          'serverVersion': '0.1.0',
          'protocolVersion': '1',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"protocolVersion"'),
          ),
        ),
      );
    });
  });
}
