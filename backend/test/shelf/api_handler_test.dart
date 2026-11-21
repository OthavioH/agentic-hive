import 'package:agentic_hive_backend/src/db/database_health_check.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final startedAt = DateTime.utc(2026, 11, 20, 12);
  const dataDir = '/data/agentic-hive';
  const version = '9.8.7';

  late FakeDatabaseHealthCheck healthCheck;
  late int webSocketCalls;
  late Handler handler;

  setUp(() {
    healthCheck = FakeDatabaseHealthCheck(
      const DatabaseStatus(ok: true, schemaVersion: 3),
    );
    webSocketCalls = 0;
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: healthCheck,
        version: version,
        dataDir: dataDir,
        startedAt: startedAt,
        now: () =>
            startedAt.add(const Duration(seconds: 90, milliseconds: 900)),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (request) {
        webSocketCalls++;
        return Response(418);
      },
    );
  });

  group('GET /health', () {
    test('answers 200 {"status":"ok"} as JSON', () async {
      final response = await handler(buildRequest('/health'));

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], startsWith('application/json'));
      expect(await readJson(response), {'status': 'ok'});
    });
  });

  group('GET /api/v1/status', () {
    test('answers 200 ok with version, uptime, data dir and schema', () async {
      final response = await handler(buildRequest('/api/v1/status'));

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], startsWith('application/json'));
      expect(await readJson(response), {
        'status': 'ok',
        'version': version,
        'uptimeSeconds': 90,
        'dataDir': dataDir,
        'database': {'status': 'ok', 'schemaVersion': 3},
        'activeRuns': 0,
      });
      expect(healthCheck.calls, 1);
    });

    test('answers 503 degraded when the database check fails', () async {
      healthCheck.result = const DatabaseStatus(
        ok: false,
        error: 'database_unavailable',
      );

      final response = await handler(buildRequest('/api/v1/status'));

      expect(response.statusCode, 503);
      expect(response.headers['content-type'], startsWith('application/json'));
      expect(await readJson(response), {
        'status': 'degraded',
        'version': version,
        'uptimeSeconds': 90,
        'dataDir': dataDir,
        'database': {'status': 'error', 'error': 'database_unavailable'},
        'activeRuns': 0,
      });
    });
  });

  group('unknown route', () {
    for (final (method, path) in [
      ('GET', '/nope'),
      ('GET', '/api/v1/unknown'),
      ('POST', '/health'),
      ('DELETE', '/api/v1/status'),
    ]) {
      test('$method $path answers 404 not_found with the request id', () async {
        final response = await handler(buildRequest(path, method: method));

        expect(response.statusCode, 404);
        expect(
          response.headers['content-type'],
          startsWith('application/json'),
        );
        final requestId = response.headers[requestIdHeader];
        expect(requestId, isNotNull);
        expect(await readJson(response), {
          'error': {
            'code': ApiErrorCode.notFound,
            'message': 'Route not found.',
            'requestId': requestId,
          },
        });
      });
    }
  });

  group('Origin header', () {
    for (final path in ['/health', '/api/v1/status', '/ws', '/nope']) {
      test('GET $path with Origin answers 403 origin_not_allowed', () async {
        final response = await handler(
          buildRequest(
            path,
            headers: {
              'origin': 'https://evil.example',
              'connection': 'Upgrade',
              'upgrade': 'websocket',
              'sec-websocket-version': '13',
              'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==',
            },
          ),
        );

        expect(response.statusCode, 403);
        final requestId = response.headers[requestIdHeader];
        expect(requestId, isNotNull);
        expect(await readJson(response), {
          'error': {
            'code': ApiErrorCode.originNotAllowed,
            'message': 'Requests with an Origin header are not accepted.',
            'requestId': requestId,
          },
        });
        expect(webSocketCalls, 0);
        expect(healthCheck.calls, 0);
      });
    }

    test('an empty Origin header is rejected too', () async {
      final response = await handler(
        buildRequest('/health', headers: {'Origin': ''}),
      );

      expect(response.statusCode, 403);
    });
  });

  group('GET /ws without Origin', () {
    test('reaches the WebSocket handler', () async {
      final response = await handler(buildRequest('/ws'));

      expect(response.statusCode, 418);
      expect(webSocketCalls, 1);
    });
  });

  group('x-request-id', () {
    test('every response carries one, including errors', () async {
      final requests = [
        buildRequest('/health'),
        buildRequest('/api/v1/status'),
        buildRequest('/nope'),
        buildRequest('/ws'),
        buildRequest('/health', headers: {'origin': 'https://evil.example'}),
      ];

      for (final request in requests) {
        final response = await handler(request);
        expect(
          response.headers[requestIdHeader],
          matches(RegExp(r'^[0-9a-f]{32}$')),
          reason: '${request.method} ${request.url}',
        );
      }
    });

    test('differs per request', () async {
      final ids = <String?>{};
      for (var i = 0; i < 20; i++) {
        final response = await handler(buildRequest('/health'));
        ids.add(response.headers[requestIdHeader]);
      }

      expect(ids, hasLength(20));
    });

    test('ignores the id sent by the client', () async {
      const clientId = 'client-chosen-id';

      final response = await handler(
        buildRequest('/nope', headers: {requestIdHeader: clientId}),
      );

      final requestId = response.headers[requestIdHeader];
      expect(requestId, isNot(clientId));
      expect(requestId, matches(RegExp(r'^[0-9a-f]{32}$')));
      final body = await readJson(response);
      expect((body['error']! as JsonMap)['requestId'], requestId);
    });
  });

  group('unhandled error inside a route', () {
    test('answers 500 internal_error with the request id', () async {
      final failing = buildApiHandler(
        statusHandler: StatusHandler(
          databaseHealthCheck: _ThrowingHealthCheck(),
          version: version,
          dataDir: dataDir,
          startedAt: startedAt,
        ),
        shutdownHandler: ShutdownHandler(onShutdown: () async {}),
        webSocketHandler: (request) => Response(418),
      );

      final response = await failing(buildRequest('/api/v1/status'));

      expect(response.statusCode, 500);
      final requestId = response.headers[requestIdHeader];
      expect(await readJson(response), {
        'error': {
          'code': ApiErrorCode.internalError,
          'message': 'Internal server error.',
          'requestId': requestId,
        },
      });
    });
  });
}

final class _ThrowingHealthCheck implements DatabaseHealthCheck {
  @override
  Future<DatabaseStatus> check() => throw StateError('boom');
}
