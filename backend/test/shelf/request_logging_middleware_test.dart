import 'package:agentic_hive_backend/src/http/middleware/request_id_middleware.dart';
import 'package:agentic_hive_backend/src/http/middleware/request_logging_middleware.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const requestId = 'req-456';
  final logs = LogCapture();

  setUp(logs.attach);
  tearDown(logs.detach);

  Handler wrap(Handler inner) => const Pipeline()
      .addMiddleware(requestIdMiddleware(generateId: () => requestId))
      .addMiddleware(requestLoggingMiddleware())
      .addHandler(inner);

  List<LogRecord> httpRecords() =>
      logs.records.where((r) => r.loggerName == 'http').toList();

  test('logs one INFO http.request without the query string', () async {
    final handler = wrap((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return Response(201);
    });

    final response = await handler(
      buildRequest('/api/v1/runs?prompt=secret&token=abc', method: 'POST'),
    );

    expect(response.statusCode, 201);
    final records = httpRecords();
    expect(records, hasLength(1));
    final record = records.single;
    expect(record.level, Level.INFO);
    final event = record.object! as LogEvent;
    expect(event.name, 'http.request');
    expect(event.userContent, isNull);
    expect(
      event.fields.keys,
      unorderedEquals(['method', 'path', 'status', 'durationMs', 'requestId']),
    );
    expect(event.fields['method'], 'POST');
    expect(event.fields['path'], '/api/v1/runs');
    expect(event.fields['status'], 201);
    expect(event.fields['requestId'], requestId);
    expect(event.fields['durationMs'], isA<int>());
    expect(event.fields['durationMs']! as int, greaterThanOrEqualTo(15));
    expect(record.toString(), isNot(contains('secret')));
  });

  test('logs the status of error responses', () async {
    final handler = wrap((request) => Response.notFound('nope'));

    await handler(buildRequest('/missing'));

    final event = httpRecords().single.object! as LogEvent;
    expect(event.name, 'http.request');
    expect(event.fields['status'], 404);
    expect(event.fields['path'], '/missing');
  });

  test('logs http.upgrade and rethrows on HijackException', () async {
    final handler = wrap((request) => throw const HijackException());

    await expectLater(
      () => handler(buildRequest('/ws')),
      throwsA(isA<HijackException>()),
    );

    final records = httpRecords();
    expect(records, hasLength(1));
    expect(records.single.level, Level.INFO);
    final event = records.single.object! as LogEvent;
    expect(event.name, 'http.upgrade');
    expect(event.fields, {
      'method': 'GET',
      'path': '/ws',
      'requestId': requestId,
    });
  });

  test('the capture restores the previous root level', () async {
    final capture = LogCapture();
    Logger.root.level = Level.WARNING;

    capture.attach();
    expect(Logger.root.level, Level.ALL);
    await capture.detach();

    expect(Logger.root.level, Level.WARNING);
  });
}
