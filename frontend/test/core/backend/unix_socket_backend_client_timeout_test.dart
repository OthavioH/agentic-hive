// Real sockets and timers leak into other files when bundled by very_good test.
@Tags(['skip_very_good_optimization'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/backend/server_info.dart';
import 'package:agentic_hive_frontend/core/backend/unix_socket_backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const int _connectTimeoutMs = 30;
const int _requestTimeoutMs = 250;
const int _slowSuccessDelayMs = 80;
const int _tooSlowDelayMs = 400;

final class _TestPlatformPaths implements PlatformPaths {
  new(this._dataDir);

  final String _dataDir;

  @override
  p.Context get context => p.context;

  @override
  String defaultDataDir() => _dataDir;

  @override
  String serverInfoPath() => context.join(_dataDir, 'server.json');
}

final class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  ContentType? contentType;
}

final class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  new({required this.statusCode, required this._stream});

  @override
  final int statusCode;

  final Stream<List<int>> _stream;

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) =>
      streamTransformer.bind(_stream);
}

final class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  new({
    required this._closeDelay,
    required this._bodyDelay,
    required this._statusCode,
    required this._responseBody,
  });

  final Duration _closeDelay;
  final Duration _bodyDelay;
  final int _statusCode;
  final String _responseBody;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() async {
    if (_closeDelay > Duration.zero) {
      await Future<void>.delayed(_closeDelay);
    }
    final stream = _bodyDelay > Duration.zero
        ? Stream<List<int>>.fromFuture(
            Future<List<int>>.delayed(
              _bodyDelay,
              () => utf8.encode(_responseBody),
            ),
          )
        : Stream<List<int>>.value(utf8.encode(_responseBody));
    return _FakeHttpClientResponse(statusCode: _statusCode, stream: stream);
  }
}

final class _FakeHttpClient extends Fake implements HttpClient {
  new({
    this.closeDelay = Duration.zero,
    this.bodyDelay = Duration.zero,
    this.statusCode = HttpStatus.ok,
    this.responseBody = '{}',
  });

  final Duration closeDelay;
  final Duration bodyDelay;
  final int statusCode;
  final String responseBody;

  int openCount = 0;
  int closedCount = 0;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    openCount++;
    return _FakeHttpClientRequest(
      closeDelay: closeDelay,
      bodyDelay: bodyDelay,
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  void close({bool force = false}) {
    closedCount++;
  }
}

Future<void> _writeServerJson(Directory dir) async {
  final info = ServerInfo(
    pid: pid,
    socketPath: p.join(dir.path, 'backend.sock'),
    version: '0.1.0',
    startedAt: DateTime.utc(2026, 11, 20),
  );
  await File(p.join(dir.path, 'server.json'))
      .writeAsString(jsonEncode(info.toJson()));
}

void main() {
  group('UnixSocketBackendClient timeouts', () {
    late Directory tempDir;
    late PlatformPaths paths;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_timeout_test_');
      paths = _TestPlatformPaths(tempDir.path);
      await _writeServerJson(tempDir);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('sendJsonRequest POST succeeds when response exceeds connectTimeout '
        'but finishes within requestTimeout', () async {
      final fakeClient = _FakeHttpClient(
        closeDelay: const Duration(milliseconds: _slowSuccessDelayMs),
        statusCode: HttpStatus.created,
        responseBody: '{"id":"run-1"}',
      );
      final client = UnixSocketBackendClient(
        platformPaths: paths,
        connectTimeout: const Duration(milliseconds: _connectTimeoutMs),
        requestTimeout: const Duration(milliseconds: _requestTimeoutMs),
        httpClientFactory: (_) => fakeClient,
      );
      addTearDown(client.close);

      final result = await client.sendJsonRequest(
        'POST',
        '/api/v1/runs',
        body: {'workflowId': 'wf-1', 'workspacePath': '/tmp/ws'},
      );

      expect(result, isA<Success<JsonMap>>());
      expect((result as Success<JsonMap>).value['id'], 'run-1');
    });

    test('sendJsonRequest POST succeeds when body read exceeds connectTimeout '
        'but finishes within requestTimeout', () async {
      final fakeClient = _FakeHttpClient(
        bodyDelay: const Duration(milliseconds: _slowSuccessDelayMs),
        statusCode: HttpStatus.created,
        responseBody: '{"id":"run-2"}',
      );
      final client = UnixSocketBackendClient(
        platformPaths: paths,
        connectTimeout: const Duration(milliseconds: _connectTimeoutMs),
        requestTimeout: const Duration(milliseconds: _requestTimeoutMs),
        httpClientFactory: (_) => fakeClient,
      );
      addTearDown(client.close);

      final result = await client.sendJsonRequest('POST', '/api/v1/runs');

      expect(result, isA<Success<JsonMap>>());
      expect((result as Success<JsonMap>).value['id'], 'run-2');
    });

    test('putJson and delete use requestTimeout', () async {
      final fakeClient = _FakeHttpClient(
        closeDelay: const Duration(milliseconds: _slowSuccessDelayMs),
        responseBody: '{"ok":true}',
      );
      final client = UnixSocketBackendClient(
        platformPaths: paths,
        connectTimeout: const Duration(milliseconds: _connectTimeoutMs),
        requestTimeout: const Duration(milliseconds: _requestTimeoutMs),
        httpClientFactory: (_) => fakeClient,
      );
      addTearDown(client.close);

      final putResult = await client.putJson('/api/v1/settings', {'a': 1});
      expect(putResult, isA<Success<JsonMap>>());

      final deleteResult = await client.delete('/api/v1/runs/run-1');
      expect(deleteResult, isA<Success<void>>());
    });

    test('getJson and postJson use injected requestTimeout', () async {
      final fakeClient = _FakeHttpClient(
        closeDelay: const Duration(milliseconds: _slowSuccessDelayMs),
        responseBody: '{"items":[]}',
      );
      final client = UnixSocketBackendClient(
        platformPaths: paths,
        connectTimeout: const Duration(milliseconds: _connectTimeoutMs),
        requestTimeout: const Duration(milliseconds: _requestTimeoutMs),
        httpClientFactory: (_) => fakeClient,
      );
      addTearDown(client.close);

      final getResult = await client.getJson('/api/v1/workflows');
      expect(getResult, isA<Success<JsonMap>>());

      final postResult = await client.postJson('/api/v1/runs', body: {});
      expect(postResult, isA<Success<JsonMap>>());
    });

    test('shutdown uses requestTimeout', () async {
      final fakeClient = _FakeHttpClient(
        closeDelay: const Duration(milliseconds: _slowSuccessDelayMs),
        statusCode: HttpStatus.accepted,
        responseBody: jsonEncode(const ShutdownResponse().toJson()),
      );
      final client = UnixSocketBackendClient(
        platformPaths: paths,
        connectTimeout: const Duration(milliseconds: _connectTimeoutMs),
        requestTimeout: const Duration(milliseconds: _requestTimeoutMs),
        httpClientFactory: (_) => fakeClient,
      );
      addTearDown(client.close);

      final result = await client.shutdown(force: false);
      expect(result, isA<Success<ShutdownResponse>>());
    });

    test('sendJsonRequest fails with timeout and resets client when response '
        'exceeds requestTimeout', () async {
      final fakeClient = _FakeHttpClient(
        closeDelay: const Duration(milliseconds: _tooSlowDelayMs),
      );
      final client = UnixSocketBackendClient(
        platformPaths: paths,
        connectTimeout: const Duration(milliseconds: _connectTimeoutMs),
        requestTimeout: const Duration(milliseconds: _requestTimeoutMs),
        httpClientFactory: (_) => fakeClient,
      );
      addTearDown(client.close);

      final result = await client.sendJsonRequest('POST', '/api/v1/runs');

      expect(result, isA<FailureResult<JsonMap>>());
      final failure = (result as FailureResult<JsonMap>).failure;
      expect(failure, isA<NetworkFailure>());
      expect((failure as NetworkFailure).code, BackendFailureCode.timeout);
      expect(fakeClient.closedCount, greaterThanOrEqualTo(1));
    });

    test('checkStatus keeps connectTimeout and times out before '
        'requestTimeout', () async {
      final fakeClient = _FakeHttpClient(
        closeDelay: const Duration(milliseconds: _slowSuccessDelayMs),
        responseBody: jsonEncode(
          const StatusResponse(
            status: BackendStatus.ok,
            version: '0.1.0',
            uptimeSeconds: 1,
            dataDir: '/tmp/hive',
            database: DatabaseStatus(ok: true, schemaVersion: 1),
          ).toJson(),
        ),
      );
      final client = UnixSocketBackendClient(
        platformPaths: paths,
        connectTimeout: const Duration(milliseconds: _connectTimeoutMs),
        requestTimeout: const Duration(milliseconds: _requestTimeoutMs),
        httpClientFactory: (_) => fakeClient,
      );
      addTearDown(client.close);

      final result = await client.checkStatus();

      expect(result, isA<FailureResult<StatusResponse>>());
      final failure = (result as FailureResult<StatusResponse>).failure;
      expect(failure, isA<NetworkFailure>());
      expect((failure as NetworkFailure).code, BackendFailureCode.timeout);
    });
  });
}
