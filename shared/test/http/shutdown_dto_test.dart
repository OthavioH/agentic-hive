import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

Matcher _formatErrorNaming(String field) => isA<FormatException>().having(
  (e) => e.message,
  'message',
  contains('"$field"'),
);

void main() {
  group('ShutdownRequest', () {
    test('defaults force to false', () {
      const request = ShutdownRequest();

      expect(request.force, isFalse);
      expect(request.toJson(), {'force': false});
    });

    test('round-trips force: true and force: false through JSON', () {
      for (final force in [false, true]) {
        final request = ShutdownRequest(force: force);
        final decoded = ShutdownRequest.fromJson(
          _overTheWire(request.toJson()),
        );

        expect(decoded.force, force);
      }
    });

    test('defaults force to false when omitted in JSON', () {
      final decoded = ShutdownRequest.fromJson(const {});

      expect(decoded.force, isFalse);
    });

    test('throws a FormatException naming "force" when it is not a bool', () {
      expect(
        () => ShutdownRequest.fromJson({'force': 'yes'}),
        throwsA(_formatErrorNaming('force')),
      );
    });
  });

  group('ShutdownResponse', () {
    test('defaults status to "shutting_down"', () {
      const response = ShutdownResponse();

      expect(response.status, 'shutting_down');
      expect(response.toJson(), {'status': 'shutting_down'});
    });

    test('round-trips through JSON', () {
      const response = ShutdownResponse();
      final decoded = ShutdownResponse.fromJson(
        _overTheWire(response.toJson()),
      );

      expect(decoded.status, 'shutting_down');
    });

    test(
      'throws a FormatException naming "status" when it is not a string',
      () {
        expect(
          () => ShutdownResponse.fromJson({'status': 123}),
          throwsA(_formatErrorNaming('status')),
        );
      },
    );
  });
}
