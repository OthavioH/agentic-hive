import 'dart:convert';

import 'package:agentic_hive_backend/src/http/middleware/error_middleware.dart';
import 'package:agentic_hive_backend/src/http/middleware/request_id_middleware.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const requestId = 'req-123';
  final logs = LogCapture();

  setUp(logs.attach);
  tearDown(logs.detach);

  Handler wrap(Handler inner) => const Pipeline()
      .addMiddleware(requestIdMiddleware(generateId: () => requestId))
      .addMiddleware(errorMiddleware())
      .addHandler(inner);

  test('passes a normal response through untouched', () async {
    final handler = wrap((request) => Response.ok('fine'));

    final response = await handler(buildRequest('/x'));

    expect(response.statusCode, 200);
    expect(await response.readAsString(), 'fine');
    expect(logs.records.where((r) => r.level >= Level.SEVERE), isEmpty);
  });

  for (final (label, Handler inner) in <(String, Handler)>[
    ('a synchronous throw', (request) => throw StateError('secret detail')),
    (
      'an asynchronous throw',
      (request) async {
        await Future<void>.delayed(Duration.zero);
        throw const FormatException('secret detail');
      },
    ),
  ]) {
    test('turns $label into 500 internal_error without details', () async {
      final response = await wrap(inner)(
        buildRequest('/api/v1/thing?token=abc', method: 'POST'),
      );

      expect(response.statusCode, 500);
      expect(response.headers['content-type'], startsWith('application/json'));
      final raw = await response.readAsString();
      expect(raw, isNot(contains('secret detail')));
      expect(raw, isNot(contains('#0')));
      expect(raw, isNot(contains('.dart')));
      expect(jsonDecode(raw), {
        'error': {
          'code': ApiErrorCode.internalError,
          'message': 'Internal server error.',
          'requestId': requestId,
        },
      });

      final severe = logs.records
          .where((r) => r.level == Level.SEVERE)
          .toList();
      expect(severe, hasLength(1));
      final record = severe.single;
      expect(record.loggerName, 'http.error');
      expect(record.error, isNotNull);
      expect(record.stackTrace, isNotNull);
      final event = record.object! as LogEvent;
      expect(event.name, 'http.unhandled_error');
      expect(event.fields, {
        'method': 'POST',
        'path': '/api/v1/thing',
        'requestId': requestId,
      });
    });
  }

  test('rethrows HijackException instead of answering 500', () async {
    final handler = wrap((request) => throw const HijackException());

    await expectLater(
      () => handler(buildRequest('/ws')),
      throwsA(isA<HijackException>()),
    );
    expect(logs.records.where((r) => r.level >= Level.SEVERE), isEmpty);
  });
}
