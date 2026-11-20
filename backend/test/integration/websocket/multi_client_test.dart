import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/ws_harness.dart';

void main() {
  const clientCount = 4;
  late TestBackend server;
  late List<WsTestClient> clients;

  setUp(() async {
    server = await TestBackend.start();
    clients = await Future.wait([
      for (var i = 0; i < clientCount; i++) server.connect(),
    ]);
  });

  tearDown(() => server.dispose());

  test('each client gets its own hello', () async {
    final hellos = await Future.wait([for (final c in clients) c.next()]);

    for (final hello in hellos) {
      expect(hello.type, WsMessageType.serverHello);
    }
    expect(hellos.map((h) => h.id).toSet(), hasLength(clientCount));
  });

  test('each client gets only the replies to its own messages', () async {
    await Future.wait([for (final c in clients) c.next()]);

    // Round 1: every client sends at once. All round-1 replies are written
    // before any round-2 message is sent, so a reply delivered to the wrong
    // client would show up ahead of that client's round-2 reply.
    for (final round in [1, 2]) {
      for (final (i, client) in clients.indexed) {
        client.sendEnvelope(WsEnvelope(type: 'nope', id: 'c$i-r$round'));
      }
      final replies = await Future.wait([
        for (final client in clients) client.next(),
      ]);
      for (final (i, reply) in replies.indexed) {
        expect(errorPayloadOf(reply).replyTo, 'c$i-r$round');
      }
    }

    for (final client in clients) {
      expect(client.received, hasLength(3), reason: 'hello + 2 replies');
    }
  });

  test('one client closing does not disturb the others', () async {
    await Future.wait([for (final c in clients) c.next()]);
    await clients.first.close();
    await server.logs.waitFor('ws.disconnected');

    for (final (i, client) in clients.skip(1).indexed) {
      client.sendEnvelope(WsEnvelope(type: 'nope', id: 'survivor-$i'));
      expect(errorPayloadOf(await client.next()).replyTo, 'survivor-$i');
    }
  });
}
