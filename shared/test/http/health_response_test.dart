import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('HealthResponse', () {
    test('defaults to status "ok"', () {
      expect(const HealthResponse().toJson(), {'status': 'ok'});
    });

    test('round-trips through JSON', () {
      const health = HealthResponse();
      final wire =
          jsonDecode(jsonEncode(health.toJson())) as Map<String, Object?>;

      expect(HealthResponse.fromJson(wire).status, 'ok');
    });

    test('throws a FormatException naming "status" when it is not a '
        'string', () {
      expect(
        () => HealthResponse.fromJson({'status': 1}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"status"'),
          ),
        ),
      );
    });
  });
}
