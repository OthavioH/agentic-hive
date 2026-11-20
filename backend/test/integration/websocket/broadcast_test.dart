import 'dart:io';

import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_backend/src/ws/ws_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'support/ws_harness.dart';

/// Serves a bare [WsGateway] (no Backend, no middleware) on a temporary Unix
/// socket, to reach [ConnectionRegistry.broadcast] directly.
void main() {
  late Directory dir;
  late HttpServer httpServer;
  late ConnectionRegistry registry;
  late LogEvents logs;
  late String socketPath;
  final clients = <WsTestClient>[];

  setUp(() async {
    logs = LogEvents();
    dir = await createShortTempDir();
    socketPath = p.join(dir.path, 'gw.sock');
    registry = ConnectionRegistry();
    final gateway = WsGateway(
      registry: registry,
      pingInterval: const Duration(seconds: 20),
      serverVersion: 'test',
    );
    httpServer = await shelf_io.serve(
      gateway.handler,
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
  });

  tearDown(() async {
    for (final client in clients) {
      await client.close();
    }
    clients.clear();
    // Wait until the gateway removed every client.
    await logs.waitUntil(
      () =>
          logs.named('ws.disconnected').length >=
          logs.named('ws.connected').length,
    );
    expect(registry.count, 0);
    await httpServer.close(force: true);
    await logs.dispose();
    await deleteDir(dir);
  });

  Future<WsTestClient> connect() async {
    final client = await WsTestClient.connect(socketPath);
    clients.add(client);
    expect((await client.next()).type, WsMessageType.serverHello);
    return client;
  }

  test('broadcast reaches every open client exactly once', () async {
    final all = [await connect(), await connect(), await connect()];
    expect(registry.count, 3);

    registry.broadcast(
      const WsEnvelope(type: 'test.event', id: 'b1', payload: {'n': 1}),
    );
    final received = await Future.wait([for (final c in all) c.next()]);

    for (final envelope in received) {
      expect(envelope.type, 'test.event');
      expect(envelope.id, 'b1');
      expect(envelope.payload, {'n': 1});
    }
    // A follow-up reply arriving next proves no duplicate broadcast frame.
    for (final (i, client) in all.indexed) {
      client.sendEnvelope(WsEnvelope(type: 'nope', id: 'after-b-$i'));
      expect(errorPayloadOf(await client.next()).replyTo, 'after-b-$i');
    }
  });

  test('broadcast skips a client that disconnected', () async {
    final leaving = await connect();
    final staying = await connect();
    final leavingId = logs.named('ws.connected').first.fields['connectionId'];

    await leaving.close();
    await logs.waitFor(
      'ws.disconnected',
      where: (fields) => fields['connectionId'] == leavingId,
    );
    expect(registry.count, 1);

    registry.broadcast(const WsEnvelope(type: 'test.event', id: 'b2'));

    expect((await staying.next()).id, 'b2');
    expect(leaving.received, hasLength(1), reason: 'only the hello');
  });

  test('closeAll closes every client with the server-shutdown code and empties '
      'the registry', () async {
    final all = [await connect(), await connect()];

    await registry.closeAll().timeout(waitTimeout);
    await Future.wait([for (final c in all) c.waitClosed()]);

    expect(registry.count, 0);
    for (final client in all) {
      expect(client.closeCode, WsCloseCode.serverShuttingDown);
    }
  });
}
