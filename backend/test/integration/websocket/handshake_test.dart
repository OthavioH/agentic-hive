import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/ws_harness.dart';

void main() {
  late TestBackend server;

  setUp(() async {
    server = await TestBackend.start();
  });

  tearDown(() => server.dispose());

  test('the first message after connecting is server.hello', () async {
    final client = await server.connect();

    final hello = await client.next();

    expect(hello.type, WsMessageType.serverHello);
    expect(hello.id, isNotEmpty);
    final payload = ServerHelloPayload.fromJson(hello.payload);
    expect(payload.serverVersion, backendVersion);
    expect(payload.protocolVersion, wsProtocolVersion);
    expect(client.received, hasLength(1));
  });

  test('a handshake with an Origin header fails with 403', () async {
    await expectLater(
      server.connect(headers: {'Origin': 'http://evil.example'}),
      throwsA(
        isA<WebSocketException>().having(
          (e) => e.httpStatusCode,
          'httpStatusCode',
          HttpStatus.forbidden,
        ),
      ),
    );
  });

  test('the Origin rejection answers the ApiError body', () async {
    final http = unixSocketHttpClient(server.socketPath);
    addTearDown(() => http.close(force: true));

    final request = await http.getUrl(Uri.parse('http://localhost/ws'));
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Key', base64Encode(List.filled(16, 7)))
      ..set('Sec-WebSocket-Version', '13')
      ..set('Origin', 'http://evil.example');
    final response = await request.close().timeout(waitTimeout);
    final body = await utf8.decodeStream(response).timeout(waitTimeout);

    expect(response.statusCode, HttpStatus.forbidden);
    final error = ApiError.fromJson(jsonDecode(body) as JsonMap);
    expect(error.code, ApiErrorCode.originNotAllowed);
  });

  test('the server still accepts clients after a rejected handshake', () async {
    await expectLater(
      server.connect(headers: {'Origin': 'null'}),
      throwsA(isA<WebSocketException>()),
    );

    final client = await server.connect();

    expect((await client.next()).type, WsMessageType.serverHello);
  });
}
