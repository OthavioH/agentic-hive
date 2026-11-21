import 'dart:convert';

import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_backend/src/ws/ws_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Headers of a valid WebSocket handshake as `dart:io` sends it, without
/// `Origin` (the Flutter app never sends one).
const _upgradeHeaders = {
  'connection': 'Upgrade',
  'upgrade': 'websocket',
  'sec-websocket-version': '13',
  'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==',
};

Request _wsRequest({
  String method = 'GET',
  Map<String, String> headers = _upgradeHeaders,
  String protocolVersion = '1.1',
  void Function()? onHijack,
}) => Request(
  method,
  Uri.parse('http://localhost/ws'),
  headers: headers,
  protocolVersion: protocolVersion,
  onHijack: onHijack == null ? null : (callback) => onHijack(),
);

Map<String, String> _without(String header) =>
    Map.of(_upgradeHeaders)..remove(header);

void main() {
  late ConnectionRegistry registry;
  late Handler gateway;

  setUp(() {
    registry = ConnectionRegistry();
    gateway = WsGateway(
      registry: registry,
      pingInterval: const Duration(seconds: 30),
      serverVersion: '0.1.0',
      generateId: () => 'id',
    ).handler;
  });

  group('WsGateway.handler rejects a non-upgrade request', () {
    for (final (label, method, headers, protocolVersion, status) in [
      (
        'plain GET without upgrade headers',
        'GET',
        <String, String>{},
        '1.1',
        426,
      ),
      ('POST with upgrade headers', 'POST', _upgradeHeaders, '1.1', 426),
      ('missing Connection', 'GET', _without('connection'), '1.1', 426),
      (
        'Connection without the upgrade token',
        'GET',
        {..._upgradeHeaders, 'connection': 'keep-alive'},
        '1.1',
        426,
      ),
      ('missing Upgrade', 'GET', _without('upgrade'), '1.1', 426),
      (
        'Upgrade other than websocket',
        'GET',
        {..._upgradeHeaders, 'upgrade': 'h2c'},
        '1.1',
        426,
      ),
      (
        'missing Sec-WebSocket-Version',
        'GET',
        _without('sec-websocket-version'),
        '1.1',
        400,
      ),
      (
        'Sec-WebSocket-Version other than 13',
        'GET',
        {..._upgradeHeaders, 'sec-websocket-version': '8'},
        '1.1',
        426,
      ),
      ('HTTP/1.0', 'GET', _upgradeHeaders, '1.0', 400),
      (
        'missing Sec-WebSocket-Key',
        'GET',
        _without('sec-websocket-key'),
        '1.1',
        400,
      ),
    ]) {
      test('$label -> $status, not upgraded', () async {
        var hijackCalls = 0;

        final response = await gateway(
          _wsRequest(
            method: method,
            headers: headers,
            protocolVersion: protocolVersion,
            onHijack: () => hijackCalls++,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(response.statusCode, status);
        expect(
          response.headers['content-type'],
          startsWith('application/json'),
        );
        final error = ApiError.fromJson(
          jsonDecode(await response.readAsString()) as Map<String, Object?>,
        );
        expect(
          error.code,
          status == 426
              ? ApiErrorCode.upgradeRequired
              : ApiErrorCode.invalidWebSocketHandshake,
        );
        expect(hijackCalls, 0);
        expect(registry.count, 0);
      });
    }
  });

  group('WsGateway.handler accepts a valid handshake', () {
    test('hijacks the connection (throws HijackException)', () async {
      var hijackCalls = 0;

      await expectLater(
        () => gateway(_wsRequest(onHijack: () => hijackCalls++)),
        throwsA(isA<HijackException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(hijackCalls, 1);
    });

    test('throws ArgumentError when the adapter cannot hijack', () async {
      await expectLater(
        () => gateway(_wsRequest()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GET /ws through buildApiHandler with the real gateway', () {
    late Handler api;

    setUp(() {
      api = buildApiHandler(
        statusHandler: StatusHandler(
          databaseHealthCheck: FakeDatabaseHealthCheck(
            const DatabaseStatus(ok: true, schemaVersion: 1),
          ),
          version: '0.1.0',
          dataDir: '/data',
          startedAt: DateTime.utc(2026),
        ),
        shutdownHandler: ShutdownHandler(onShutdown: () async {}),
        webSocketHandler: gateway,
      );
    });

    test('a plain GET is not upgraded: 426 with the ApiError body', () async {
      final response = await api(buildRequest('/ws'));

      expect(response.statusCode, 426);
      final requestId = response.headers[requestIdHeader];
      expect(requestId, isNotNull);
      expect(response.headers['content-type'], startsWith('application/json'));
      final error = ApiError.fromJson(
        jsonDecode(await response.readAsString()) as Map<String, Object?>,
      );
      expect(error.code, ApiErrorCode.upgradeRequired);
      expect(error.requestId, requestId);
    });

    test('a valid handshake propagates HijackException', () async {
      var hijackCalls = 0;

      await expectLater(
        () => api(_wsRequest(onHijack: () => hijackCalls++)),
        throwsA(isA<HijackException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(hijackCalls, 1);
    });

    test('a valid handshake with Origin is rejected before hijack', () async {
      var hijackCalls = 0;

      final response = await api(
        _wsRequest(
          headers: {..._upgradeHeaders, 'origin': 'http://localhost'},
          onHijack: () => hijackCalls++,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(response.statusCode, 403);
      expect(
        ((await readJson(response))['error']! as JsonMap)['code'],
        ApiErrorCode.originNotAllowed,
      );
      expect(hijackCalls, 0);
    });
  });
}
