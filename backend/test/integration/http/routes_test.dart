@Timeout(Duration(seconds: 60))
library;

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late String dataDir;
  late SocketHttpClient client;

  setUp(() async {
    dataDir = (await createTempDir()).path;
    final backend = await startBackend(dataDir);
    client = openClient(backend.socketPath);
  });

  group('GET /health', () {
    test('answers 200 with a HealthResponse over the Unix socket', () async {
      final response = await client.get('/health');

      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'application/json');
      expect(response.headers.value('x-request-id'), isNotEmpty);
      expect(HealthResponse.fromJson(response.json).status, 'ok');
    });
  });

  group('GET /api/v1/status', () {
    test('answers 200 with a StatusResponse and a healthy database', () async {
      final response = await client.get('/api/v1/status');

      expect(response.statusCode, 200);
      final status = StatusResponse.fromJson(response.json);
      expect(status.status, BackendStatus.ok);
      expect(status.version, backendVersion);
      expect(status.dataDir, dataDir);
      expect(status.uptimeSeconds, greaterThanOrEqualTo(0));
      expect(status.database.ok, isTrue);
      expect(status.database.schemaVersion, 9);
      expect(status.database.error, isNull);
    });
  });

  group('errors', () {
    test('an unknown route answers 404 with an ApiError', () async {
      final response = await client.get('/api/v1/does-not-exist');

      expect(response.statusCode, 404);
      final error = ApiError.fromJson(response.json);
      expect(error.code, ApiErrorCode.notFound);
      expect(error.message, isNotEmpty);
      expect(error.requestId, response.headers.value('x-request-id'));
      expect(response.body, isNot(contains('#0')));
    });

    for (final path in ['/health', '/api/v1/status', '/nowhere']) {
      test('a request to $path with an Origin header answers 403', () async {
        final response = await client.get(
          path,
          headers: {'origin': 'http://evil.example'},
        );

        expect(response.statusCode, 403);
        final error = ApiError.fromJson(response.json);
        expect(error.code, ApiErrorCode.originNotAllowed);
        expect(error.requestId, response.headers.value('x-request-id'));
      });
    }
  });
}
