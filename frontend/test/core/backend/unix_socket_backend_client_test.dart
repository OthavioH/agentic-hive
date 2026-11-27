// Real sockets and timers leak into other files when bundled by very_good test.
@Tags(['skip_very_good_optimization'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/backend/server_info.dart';
import 'package:agentic_hive_frontend/core/backend/unix_socket_backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

Future<void> _writeServerJson(
  Directory dir, {
  required String socketPath,
}) async {
  final info = ServerInfo(
    pid: pid,
    socketPath: socketPath,
    version: '0.1.0',
    startedAt: DateTime.utc(2026, 11, 20),
  );
  await File(p.join(dir.path, 'server.json'))
      .writeAsString(jsonEncode(info.toJson()));
}

void main() {
  group('UnixSocketBackendClient', () {
    late Directory tempDir;
    late String socketPath;
    late PlatformPaths paths;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_unix_test_');
      socketPath = p.join(tempDir.path, 'backend.sock');
      paths = _TestPlatformPaths(tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns notRunning when server.json is missing', () async {
      final client = UnixSocketBackendClient(platformPaths: paths);
      addTearDown(client.close);

      final result = await client.checkStatus();
      expect(result, isA<FailureResult<StatusResponse>>());
      final failure = (result as FailureResult<StatusResponse>).failure;
      expect(failure, isA<NetworkFailure>());
      expect((failure as NetworkFailure).code, BackendFailureCode.notRunning);
    });

    test('discovers server.json, checks status, completes server.hello, '
        'and exchanges WsEnvelope', () async {
      await _writeServerJson(tempDir, socketPath: socketPath);
      final server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      final serverSockets = <WebSocket>[];
      addTearDown(server.close);
      addTearDown(() async {
        for (final ws in serverSockets) {
          await ws.close();
        }
      });

      final serverReceived = <WsEnvelope>[];
      server.listen((request) async {
        if (request.uri.path == '/api/v1/status') {
          const payload = StatusResponse(
            status: BackendStatus.ok,
            version: '0.1.0',
            uptimeSeconds: 42,
            dataDir: '/tmp/hive',
            database: DatabaseStatus(ok: true, schemaVersion: 1),
          );
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..headers.set(HttpHeaders.connectionHeader, 'close')
            ..write(jsonEncode(payload.toJson()));
          await request.response.close();
          return;
        }
        if (request.uri.path == '/ws') {
          final ws = await WebSocketTransformer.upgrade(request);
          serverSockets.add(ws);
          ws
            ..add(
              jsonEncode(
                WsEnvelope(
                  type: WsMessageType.serverHello,
                  id: 'hello-1',
                  payload: const ServerHelloPayload(
                    serverVersion: '0.1.0',
                    protocolVersion: wsProtocolVersion,
                  ).toJson(),
                ).toJson(),
              ),
            )
            ..listen((raw) {
              if (raw is String) {
                serverReceived.add(
                  WsEnvelope.fromJson(jsonDecode(raw) as Map<String, Object?>),
                );
                ws.add(
                  jsonEncode(
                    const WsEnvelope(
                      type: 'run.started',
                      id: 'evt-1',
                      payload: {'runId': 'r-1'},
                    ).toJson(),
                  ),
                );
              }
            });
        }
      });

      final client = UnixSocketBackendClient(platformPaths: paths);
      addTearDown(client.close);

      final statusResult = await client.checkStatus();
      expect(statusResult, isA<Success<StatusResponse>>());

      final wsResult = await client.connectWebSocket();
      expect(wsResult, isA<Success<BackendWebSocketSession>>());
      final session = (wsResult as Success<BackendWebSocketSession>).value;
      addTearDown(session.close);

      final firstEventFuture = session.messages.first;

      const outgoing = WsEnvelope(
        type: 'run.cancel',
        id: 'cmd-1',
        payload: {'runId': 'r-1'},
      );
      final sendResult = await session.send(outgoing);
      expect(sendResult, isA<Success<void>>());

      final firstEvent = await firstEventFuture;
      expect(firstEvent.type, 'run.started');
      expect(serverReceived, [outgoing]);
    });

    test('handles 503 degraded status response', () async {
      await _writeServerJson(tempDir, socketPath: socketPath);
      final server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      addTearDown(server.close);

      server.listen((request) async {
        const payload = StatusResponse(
          status: BackendStatus.degraded,
          version: '0.1.0',
          uptimeSeconds: 1,
          dataDir: '/tmp/hive',
          database: DatabaseStatus(
            ok: false,
            schemaVersion: 1,
            error: 'SQLite locked',
          ),
        );
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.contentType = ContentType.json
          ..headers.set(HttpHeaders.connectionHeader, 'close')
          ..write(jsonEncode(payload.toJson()));
        await request.response.close();
      });

      final client = UnixSocketBackendClient(platformPaths: paths);
      addTearDown(client.close);

      final result = await client.checkStatus();
      expect(result, isA<FailureResult<StatusResponse>>());
      final failure =
          (result as FailureResult<StatusResponse>).failure as BackendFailure;
      expect(failure.code, BackendFailureCode.degraded);
      expect(failure.statusCode, HttpStatus.serviceUnavailable);
    });

    test('returns protocolMismatch on incompatible server.hello', () async {
      await _writeServerJson(tempDir, socketPath: socketPath);
      final server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      final serverSockets = <WebSocket>[];
      addTearDown(server.close);
      addTearDown(() async {
        for (final ws in serverSockets) {
          await ws.close();
        }
      });

      server.listen((request) async {
        if (request.uri.path == '/ws') {
          final ws = await WebSocketTransformer.upgrade(request);
          serverSockets.add(ws);
          ws.add(
            jsonEncode(
              WsEnvelope(
                type: WsMessageType.serverHello,
                id: 'hello-1',
                payload: const ServerHelloPayload(
                  serverVersion: '0.1.0',
                  protocolVersion: wsProtocolVersion + 99,
                ).toJson(),
              ).toJson(),
            ),
          );
        }
      });

      final client = UnixSocketBackendClient(platformPaths: paths);
      addTearDown(client.close);

      final result = await client.connectWebSocket();
      expect(result, isA<FailureResult<BackendWebSocketSession>>());
      final failure =
          (result as FailureResult<BackendWebSocketSession>).failure
              as BackendFailure;
      expect(failure.code, BackendFailureCode.protocolMismatch);
    });

    test('returns timeout when server.hello is not sent in time', () async {
      await _writeServerJson(tempDir, socketPath: socketPath);
      final server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      final serverSockets = <WebSocket>[];
      addTearDown(server.close);
      addTearDown(() async {
        for (final ws in serverSockets) {
          await ws.close();
        }
      });

      server.listen((request) async {
        if (request.uri.path == '/ws') {
          final ws = await WebSocketTransformer.upgrade(request);
          serverSockets.add(ws);
          // Intentionally never send server.hello.
        }
      });

      final client = UnixSocketBackendClient(
        platformPaths: paths,
        handshakeTimeout: HiveMotionTokens.standard.short,
      );
      addTearDown(client.close);

      final result = await client.connectWebSocket();
      expect(result, isA<FailureResult<BackendWebSocketSession>>());
      final failure =
          (result as FailureResult<BackendWebSocketSession>).failure
              as NetworkFailure;
      expect(failure.code, BackendFailureCode.timeout);
    });

    test('resets HttpClient and reconnects after server restart', () async {
      await _writeServerJson(tempDir, socketPath: socketPath);
      var server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      server.listen((request) async {
        const payload = StatusResponse(
          status: BackendStatus.ok,
          version: '0.1.0',
          uptimeSeconds: 1,
          dataDir: '/tmp/hive',
          database: DatabaseStatus(ok: true, schemaVersion: 1),
        );
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..headers.set(HttpHeaders.connectionHeader, 'close')
          ..write(jsonEncode(payload.toJson()));
        await request.response.close();
      });

      final client = UnixSocketBackendClient(platformPaths: paths);
      addTearDown(client.close);

      expect(await client.checkStatus(), isA<Success<StatusResponse>>());

      // Stop server and remove socket file, then verify failure resets client.
      await server.close();
      final sockFile = File(socketPath);
      if (sockFile.existsSync()) {
        await sockFile.delete();
      }
      expect(await client.checkStatus(), isA<FailureResult<StatusResponse>>());

      // Restart server on the same socket path and verify clean reconnect.
      server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      addTearDown(server.close);
      server.listen((request) async {
        const payload = StatusResponse(
          status: BackendStatus.ok,
          version: '0.1.0',
          uptimeSeconds: 2,
          dataDir: '/tmp/hive',
          database: DatabaseStatus(ok: true, schemaVersion: 1),
        );
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..headers.set(HttpHeaders.connectionHeader, 'close')
          ..write(jsonEncode(payload.toJson()));
        await request.response.close();
      });

      final secondResult = await client.checkStatus();
      expect(secondResult, isA<Success<StatusResponse>>());
      expect((secondResult as Success<StatusResponse>).value.uptimeSeconds, 2);
    });

    test('shutdown(force: false) posts request and returns Success on '
        '202 Accepted', () async {
      await _writeServerJson(tempDir, socketPath: socketPath);
      final server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      addTearDown(server.close);

      ShutdownRequest? receivedRequest;
      server.listen((request) async {
        if (request.method == 'POST' &&
            request.uri.path == '/api/v1/shutdown') {
          final raw = await utf8.decoder.bind(request).join();
          receivedRequest = ShutdownRequest.fromJson(
            jsonDecode(raw) as Map<String, Object?>,
          );
          const payload = ShutdownResponse();
          request.response
            ..statusCode = HttpStatus.accepted
            ..headers.contentType = ContentType.json
            ..headers.set(HttpHeaders.connectionHeader, 'close')
            ..write(jsonEncode(payload.toJson()));
          await request.response.close();
        }
      });

      final client = UnixSocketBackendClient(platformPaths: paths);
      addTearDown(client.close);

      final result = await client.shutdown(force: false);
      expect(result, isA<Success<ShutdownResponse>>());
      expect(
        (result as Success<ShutdownResponse>).value.status,
        'shutting_down',
      );
      expect(receivedRequest, const ShutdownRequest());
    });

    test(
      'shutdown(force: false) maps 409 Conflict to BackendFailure',
      () async {
        await _writeServerJson(tempDir, socketPath: socketPath);
        final server = await HttpServer.bind(
          InternetAddress(socketPath, type: InternetAddressType.unix),
          0,
        );
        addTearDown(server.close);

        ShutdownRequest? receivedRequest;
        server.listen((request) async {
          if (request.method == 'POST' &&
              request.uri.path == '/api/v1/shutdown') {
            final raw = await utf8.decoder.bind(request).join();
            receivedRequest = ShutdownRequest.fromJson(
              jsonDecode(raw) as Map<String, Object?>,
            );
            const error = ApiError(
              code: ApiErrorCode.conflict,
              message: 'Cannot shut down while 2 runs are active.',
            );
            request.response
              ..statusCode = HttpStatus.conflict
              ..headers.contentType = ContentType.json
              ..headers.set(HttpHeaders.connectionHeader, 'close')
              ..write(jsonEncode(error.toJson()));
            await request.response.close();
          }
        });

        final client = UnixSocketBackendClient(platformPaths: paths);
        addTearDown(client.close);

        final result = await client.shutdown(force: false);
        expect(result, isA<FailureResult<ShutdownResponse>>());
        final failure =
            (result as FailureResult<ShutdownResponse>).failure
                as BackendFailure;
        expect(failure.statusCode, HttpStatus.conflict);
        expect(failure.code, ApiErrorCode.conflict);
        expect(failure.message, 'Cannot shut down while 2 runs are active.');
        expect(receivedRequest, const ShutdownRequest());
      },
    );

    test('sendJsonRequest maps a 409 ApiError with details to '
        'BackendFailure.details', () async {
      await _writeServerJson(tempDir, socketPath: socketPath);
      final server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      addTearDown(server.close);

      server.listen((request) async {
        const error = ApiError(
          code: ApiErrorCode.workflowHasActiveRuns,
          message: 'Workflow has 2 active runs.',
          details: {'run-1': 'running', 'run-2': 'paused'},
        );
        request.response
          ..statusCode = HttpStatus.conflict
          ..headers.contentType = ContentType.json
          ..headers.set(HttpHeaders.connectionHeader, 'close')
          ..write(jsonEncode(error.toJson()));
        await request.response.close();
      });

      final client = UnixSocketBackendClient(platformPaths: paths);
      addTearDown(client.close);

      final result = await client.sendJsonRequest(
        'DELETE',
        '/api/v1/workflows/wf-1',
      );
      final failure = (result as FailureResult<JsonMap>).failure;
      expect(failure, isA<BackendFailure>());
      failure as BackendFailure;
      expect(failure.statusCode, HttpStatus.conflict);
      expect(failure.code, ApiErrorCode.workflowHasActiveRuns);
      expect(failure.message, 'Workflow has 2 active runs.');
      expect(failure.details, {'run-1': 'running', 'run-2': 'paused'});
    });

    test(
      'getJson maps a 409 ApiError with details to BackendFailure.details',
      () async {
        await _writeServerJson(tempDir, socketPath: socketPath);
        final server = await HttpServer.bind(
          InternetAddress(socketPath, type: InternetAddressType.unix),
          0,
        );
        addTearDown(server.close);

        server.listen((request) async {
          const error = ApiError(
            code: ApiErrorCode.revisionConflict,
            message: 'Revision changed.',
            details: {'currentRevision': 'r2'},
          );
          request.response
            ..statusCode = HttpStatus.conflict
            ..headers.contentType = ContentType.json
            ..headers.set(HttpHeaders.connectionHeader, 'close')
            ..write(jsonEncode(error.toJson()));
          await request.response.close();
        });

        final client = UnixSocketBackendClient(platformPaths: paths);
        addTearDown(client.close);

        final result = await client.getJson('/api/v1/workflows/wf-1');
        final failure = (result as FailureResult<JsonMap>).failure;
        expect(failure, isA<BackendFailure>());
        failure as BackendFailure;
        expect(failure.details, {'currentRevision': 'r2'});
      },
    );

    test('shutdown(force: true) posts force=true and returns Success on '
        '202 Accepted', () async {
      await _writeServerJson(tempDir, socketPath: socketPath);
      final server = await HttpServer.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      addTearDown(server.close);

      ShutdownRequest? receivedRequest;
      server.listen((request) async {
        if (request.method == 'POST' &&
            request.uri.path == '/api/v1/shutdown') {
          final raw = await utf8.decoder.bind(request).join();
          receivedRequest = ShutdownRequest.fromJson(
            jsonDecode(raw) as Map<String, Object?>,
          );
          const payload = ShutdownResponse();
          request.response
            ..statusCode = HttpStatus.accepted
            ..headers.contentType = ContentType.json
            ..headers.set(HttpHeaders.connectionHeader, 'close')
            ..write(jsonEncode(payload.toJson()));
          await request.response.close();
        }
      });

      final client = UnixSocketBackendClient(platformPaths: paths);
      addTearDown(client.close);

      final result = await client.shutdown(force: true);
      expect(result, isA<Success<ShutdownResponse>>());
      expect(
        (result as Success<ShutdownResponse>).value.status,
        'shutting_down',
      );
      expect(receivedRequest, const ShutdownRequest(force: true));
    });
  });
}
