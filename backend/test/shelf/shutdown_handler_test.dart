import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late int activeRuns;
  late int shutdownCalls;
  late Completer<void> shutdownTriggered;
  late Handler handler;

  setUp(() {
    activeRuns = 0;
    shutdownCalls = 0;
    shutdownTriggered = Completer<void>();
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 1),
        ),
        version: '0.1.0',
        dataDir: '/data',
        startedAt: DateTime.utc(2026),
        activeRuns: () => activeRuns,
      ),
      shutdownHandler: ShutdownHandler(
        activeRuns: () => activeRuns,
        onShutdown: () async {
          shutdownCalls++;
          if (!shutdownTriggered.isCompleted) shutdownTriggered.complete();
        },
      ),
      webSocketHandler: (_) => Response(418),
    );
  });

  group('POST /api/v1/shutdown', () {
    test(
      'answers 202 Accepted and triggers shutdown when idle with empty body',
      () async {
        final response = await handler(
          buildRequest('/api/v1/shutdown', method: 'POST'),
        );

        expect(response.statusCode, 202);
        expect(
          response.headers['content-type'],
          startsWith('application/json'),
        );
        expect(
          ShutdownResponse.fromJson(await readJson(response)).status,
          'shutting_down',
        );
        // Shutdown is scheduled asynchronously after the response is returned.
        await shutdownTriggered.future.timeout(const Duration(seconds: 2));
        expect(shutdownCalls, 1);
      },
    );

    test('answers 202 Accepted when idle and force is false', () async {
      final response = await handler(
        buildRequest(
          '/api/v1/shutdown',
          method: 'POST',
          body: jsonEncode(const ShutdownRequest()),
        ),
      );

      expect(response.statusCode, 202);
      await shutdownTriggered.future.timeout(const Duration(seconds: 2));
      expect(shutdownCalls, 1);
    });

    test('answers 409 Conflict with ApiError when activeRuns > 0 and force is '
        'omitted', () async {
      activeRuns = 2;

      final response = await handler(
        buildRequest('/api/v1/shutdown', method: 'POST'),
      );

      expect(response.statusCode, 409);
      final error = ApiError.fromJson(await readJson(response));
      expect(error.code, ApiErrorCode.conflict);
      expect(error.requestId, response.headers[requestIdHeader]);
      await Future<void>.delayed(Duration.zero);
      expect(shutdownCalls, 0);
    });

    test('answers 409 Conflict with ApiError when activeRuns > 0 and force is '
        'false', () async {
      activeRuns = 1;

      final response = await handler(
        buildRequest(
          '/api/v1/shutdown',
          method: 'POST',
          body: jsonEncode(const ShutdownRequest()),
        ),
      );

      expect(response.statusCode, 409);
      final error = ApiError.fromJson(await readJson(response));
      expect(error.code, ApiErrorCode.conflict);
      expect(error.requestId, response.headers[requestIdHeader]);
      await Future<void>.delayed(Duration.zero);
      expect(shutdownCalls, 0);
    });

    test('answers 202 Accepted and triggers shutdown when activeRuns > 0 and '
        'force is true', () async {
      activeRuns = 3;

      final response = await handler(
        buildRequest(
          '/api/v1/shutdown',
          method: 'POST',
          body: jsonEncode(const ShutdownRequest(force: true)),
        ),
      );

      expect(response.statusCode, 202);
      expect(
        ShutdownResponse.fromJson(await readJson(response)).status,
        'shutting_down',
      );
      await shutdownTriggered.future.timeout(const Duration(seconds: 2));
      expect(shutdownCalls, 1);
    });

    test('answers 400 Bad Request when the body is not valid JSON', () async {
      final response = await handler(
        buildRequest('/api/v1/shutdown', method: 'POST', body: '{bad'),
      );

      expect(response.statusCode, 400);
      final error = ApiError.fromJson(await readJson(response));
      expect(error.code, ApiErrorCode.badRequest);
      expect(error.requestId, response.headers[requestIdHeader]);
      await Future<void>.delayed(Duration.zero);
      expect(shutdownCalls, 0);
    });

    test('answers 400 Bad Request when force is not a boolean', () async {
      final response = await handler(
        buildRequest(
          '/api/v1/shutdown',
          method: 'POST',
          body: jsonEncode({'force': 'yes'}),
        ),
      );

      expect(response.statusCode, 400);
      final error = ApiError.fromJson(await readJson(response));
      expect(error.code, ApiErrorCode.badRequest);
      await Future<void>.delayed(Duration.zero);
      expect(shutdownCalls, 0);
    });

    test('rejects requests carrying an Origin header with 403', () async {
      final response = await handler(
        buildRequest(
          '/api/v1/shutdown',
          method: 'POST',
          headers: {'origin': 'https://evil.example'},
        ),
      );

      expect(response.statusCode, 403);
      final error = ApiError.fromJson(await readJson(response));
      expect(error.code, ApiErrorCode.originNotAllowed);
      await Future<void>.delayed(Duration.zero);
      expect(shutdownCalls, 0);
    });
  });
}
