import 'dart:io';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/ws_harness.dart';

void main() {
  late TestBackend server;

  setUp(() async {
    server = await TestBackend.start();
  });

  tearDown(() => server.dispose());

  LogEvents logs() => server.logs;

  Future<WsTestClient> connect() async {
    final client = await server.connect();
    expect((await client.next()).type, WsMessageType.serverHello);
    return client;
  }

  test(
    'Backend.stop closes open clients with the server-shutdown code',
    () async {
      final first = await connect();
      final second = await connect();

      await server.stop();
      await Future.wait([first.waitClosed(), second.waitClosed()]);

      for (final client in [first, second]) {
        expect(client.closeCode, WsCloseCode.serverShuttingDown);
        expect(client.closeReason, 'Server shutting down');
      }
      expect(File(server.socketPath).existsSync(), isFalse);
    },
  );

  test('a client that disconnects is removed from the server', () async {
    final first = await connect();
    final firstId = logs().named('ws.connected').single.fields['connectionId'];
    expect(logs().named('ws.connected').single.fields['open'], 1);

    await first.close();
    final disconnected = await logs().waitFor(
      'ws.disconnected',
      where: (fields) => fields['connectionId'] == firstId,
    );
    expect(disconnected.fields['closeCode'], WebSocketStatus.normalClosure);
    expect(disconnected.fields['open'], 0);

    // Reconnect: the server counts one open connection, so the first one
    // was removed, and the new one is served.
    final again = await connect();
    final reconnected = logs().named('ws.connected').last;
    expect(reconnected.fields['connectionId'], isNot(firstId));
    expect(reconnected.fields['open'], 1);
    again.sendEnvelope(const WsEnvelope(type: 'nope', id: 'after-reconnect'));
    expect(errorPayloadOf(await again.next()).replyTo, 'after-reconnect');

    // Stopping flushes the log file.
    await server.closeClients();
    await server.stop();
    final lines = readJsonLines(server.todayLogFile);
    final disconnectLines = lines.where(
      (line) =>
          line['message'] == 'ws.disconnected' &&
          (line['fields']! as JsonMap)['connectionId'] == firstId,
    );
    expect(disconnectLines, hasLength(1));
    final fields = disconnectLines.single['fields']! as JsonMap;
    expect(fields['closeCode'], WebSocketStatus.normalClosure);
    expect(fields['open'], 0);
    expect(disconnectLines.single['level'], 'INFO');
  });

  test('the logged close code is the one the client sent', () async {
    final first = await connect();
    final firstId = logs().named('ws.connected').single.fields['connectionId'];

    await first.close(4000);
    final disconnected = await logs().waitFor(
      'ws.disconnected',
      where: (fields) => fields['connectionId'] == firstId,
    );

    expect(disconnected.fields['closeCode'], 4000);
    expect(disconnected.fields['open'], 0);
  });

  test('a client that drops without a close frame is removed', () async {
    final http = unixSocketHttpClient(server.socketPath);
    addTearDown(() => http.close(force: true));
    final request = await http.getUrl(Uri.parse('http://localhost/ws'));
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==')
      ..set('Sec-WebSocket-Version', '13');
    final response = await request.close().timeout(waitTimeout);
    expect(response.statusCode, HttpStatus.switchingProtocols);
    final raw = await response.detachSocket().timeout(waitTimeout);
    final connected = await logs().waitFor('ws.connected');

    raw.destroy();
    final disconnected = await logs().waitFor(
      'ws.disconnected',
      where: (fields) =>
          fields['connectionId'] == connected.fields['connectionId'],
    );

    expect(disconnected.fields['open'], 0);
    final again = await connect();
    again.sendEnvelope(const WsEnvelope(type: 'nope', id: 'after-drop'));
    expect(errorPayloadOf(await again.next()).replyTo, 'after-drop');
    expect(logs().named('ws.connected').last.fields['open'], 1);
  });
}
