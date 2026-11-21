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
  group('StatusResponse', () {
    test('round-trips an ok status through JSON', () {
      const status = StatusResponse(
        status: BackendStatus.ok,
        version: '0.1.0',
        uptimeSeconds: 42,
        dataDir: '/data/agentic-hive',
        database: DatabaseStatus(ok: true, schemaVersion: 1),
      );

      final decoded = StatusResponse.fromJson(_overTheWire(status.toJson()));

      expect(decoded.status, BackendStatus.ok);
      expect(decoded.version, '0.1.0');
      expect(decoded.uptimeSeconds, 42);
      expect(decoded.dataDir, '/data/agentic-hive');
      expect(decoded.database.ok, isTrue);
      expect(decoded.database.schemaVersion, 1);
      expect(decoded.database.error, isNull);
      expect(decoded.activeRuns, 0);
    });

    test('round-trips a non-zero activeRuns count through JSON', () {
      const status = StatusResponse(
        status: BackendStatus.ok,
        version: '0.1.0',
        uptimeSeconds: 10,
        dataDir: '/data/agentic-hive',
        database: DatabaseStatus(ok: true, schemaVersion: 1),
        activeRuns: 3,
      );

      final decoded = StatusResponse.fromJson(_overTheWire(status.toJson()));

      expect(decoded.activeRuns, 3);
    });

    test('defaults activeRuns to 0 when omitted in JSON', () {
      final decoded = StatusResponse.fromJson({
        'status': 'ok',
        'version': '0.1.0',
        'uptimeSeconds': 1,
        'dataDir': '/d',
        'database': {'status': 'ok'},
      });

      expect(decoded.activeRuns, 0);
    });

    test(
      'throws a FormatException naming "activeRuns" when it is not an int',
      () {
        expect(
          () => StatusResponse.fromJson({
            'status': 'ok',
            'version': '0.1.0',
            'uptimeSeconds': 1,
            'dataDir': '/d',
            'database': {'status': 'ok'},
            'activeRuns': '2',
          }),
          throwsA(_formatErrorNaming('activeRuns')),
        );
      },
    );

    test('round-trips a degraded status with a database error', () {
      const status = StatusResponse(
        status: BackendStatus.degraded,
        version: '0.1.0',
        uptimeSeconds: 0,
        dataDir: r'C:\data',
        database: DatabaseStatus(ok: false, error: 'database is locked'),
      );

      final decoded = StatusResponse.fromJson(_overTheWire(status.toJson()));

      expect(decoded.status, BackendStatus.degraded);
      expect(decoded.dataDir, r'C:\data');
      expect(decoded.database.ok, isFalse);
      expect(decoded.database.schemaVersion, isNull);
      expect(decoded.database.error, 'database is locked');
    });

    test('encodes the status enum by name and nests the database', () {
      const status = StatusResponse(
        status: BackendStatus.degraded,
        version: '0.1.0',
        uptimeSeconds: 5,
        dataDir: '/d',
        database: DatabaseStatus(ok: false, error: 'down'),
      );

      expect(status.toJson(), {
        'status': 'degraded',
        'version': '0.1.0',
        'uptimeSeconds': 5,
        'dataDir': '/d',
        'database': {'status': 'error', 'error': 'down'},
        'activeRuns': 0,
      });
    });

    test('throws a FormatException naming a field of the wrong type', () {
      expect(
        () => StatusResponse.fromJson({
          'status': 'ok',
          'version': '0.1.0',
          'uptimeSeconds': '42',
          'dataDir': '/d',
          'database': {'status': 'ok'},
        }),
        throwsA(_formatErrorNaming('uptimeSeconds')),
      );
    });

    test('throws a FormatException naming "database" when it is missing', () {
      expect(
        () => StatusResponse.fromJson({
          'status': 'ok',
          'version': '0.1.0',
          'uptimeSeconds': 1,
          'dataDir': '/d',
        }),
        throwsA(_formatErrorNaming('database')),
      );
    });

    test('throws a FormatException for an unknown status value', () {
      expect(
        () => StatusResponse.fromJson({
          'status': 'exploded',
          'version': '0.1.0',
          'uptimeSeconds': 1,
          'dataDir': '/d',
          'database': {'status': 'ok'},
        }),
        throwsFormatException,
      );
    });
  });

  group('DatabaseStatus', () {
    test('omits schemaVersion and error from JSON when they are null', () {
      expect(const DatabaseStatus(ok: true).toJson(), {'status': 'ok'});
    });

    test('encodes ok as "ok" and a failure as "error"', () {
      expect(const DatabaseStatus(ok: true, schemaVersion: 3).toJson(), {
        'status': 'ok',
        'schemaVersion': 3,
      });
      expect(const DatabaseStatus(ok: false, error: 'x').toJson(), {
        'status': 'error',
        'error': 'x',
      });
    });

    test('throws a FormatException naming "schemaVersion" when it is not an '
        'int', () {
      expect(
        () => DatabaseStatus.fromJson({'status': 'ok', 'schemaVersion': '1'}),
        throwsA(_formatErrorNaming('schemaVersion')),
      );
    });
  });
}
