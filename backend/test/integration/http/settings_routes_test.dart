@Timeout(Duration(seconds: 60))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

import 'support/harness.dart';

void main() {
  late Directory tempDir;
  late Backend backend;
  late SocketHttpClient client;

  setUp(() async {
    tempDir = await createTempDir();
    backend = await startBackend(tempDir.path);
    client = openClient(backend.socketPath);
  });

  test('GET/PUT /api/v1/settings persists, reloads F2 agents, broadcasts '
      'settings.updated, and survives restart', () async {
    final customAgentsDir = Directory(p.join(tempDir.path, 'custom-agents'))
      ..createSync();
    File(p.join(customAgentsDir.path, 'planner.md'))
        .writeAsStringSync('---\nname: Planner\n---\nPlan tasks.');

    final ws = await _connectWs(backend.socketPath);
    addTearDown(ws.close);
    expect((await ws.next()).type, WsMessageType.serverHello);

    // Initial GET returns default agentsDir.
    final initialRes = await client.get('/api/v1/settings');
    expect(initialRes.statusCode, 200);
    final initial = AppSettings.fromJson(initialRes.json);
    expect(initial.agentsDir, p.join(tempDir.path, 'agents'));

    // PUT updates agentsDir -> reloads F2 and broadcasts settings.updated.
    final putRes = await client.put(
      '/api/v1/settings',
      body: jsonEncode(
        UpdateSettingsRequest(
          agentsDir: customAgentsDir.path,
          defaultWorkspaceDir: tempDir.path,
        ).toJson(),
      ),
    );
    expect(putRes.statusCode, 200);
    final updated = AppSettings.fromJson(putRes.json);
    expect(updated.agentsDir, customAgentsDir.path);
    expect(updated.defaultWorkspaceDir, tempDir.path);

    final wsEvent = await ws.next();
    expect(wsEvent.type, WsMessageType.settingsUpdated);
    final payload = SettingsUpdatedPayload.fromJson(wsEvent.payload);
    expect(payload.settings, updated);

    // F2 GET /api/v1/agents now reads from customAgentsDir without restart.
    final agentsRes = await client.get('/api/v1/agents');
    expect(agentsRes.statusCode, 200);
    final agents = AgentListResponse.fromJson(agentsRes.json);
    expect(agents.agents.map((a) => a.id), ['planner']);

    // Restart backend and verify persisted settings still apply.
    await ws.close();
    await backend.stop();

    final restarted = await startBackend(tempDir.path);
    final restartedClient = openClient(restarted.socketPath);
    final afterRestartRes = await restartedClient.get('/api/v1/settings');
    expect(afterRestartRes.statusCode, 200);
    expect(AppSettings.fromJson(afterRestartRes.json), updated);

    final restartedAgentsRes = await restartedClient.get('/api/v1/agents');
    expect(restartedAgentsRes.statusCode, 200);
    expect(
      AgentListResponse.fromJson(restartedAgentsRes.json).agents
          .map((a) => a.id),
      ['planner'],
    );
  });
}

Future<_WsClient> _connectWs(String socketPath) async {
  final socket = await Socket.connect(
    InternetAddress(socketPath, type: InternetAddressType.unix),
    0,
  );
  final client = HttpClient()
    ..connectionFactory = (uri, proxyHost, proxyPort) =>
        Future.value(ConnectionTask.fromSocket(Future.value(socket), () {}));
  final webSocket = await WebSocket.connect(
    'ws://localhost/ws',
    customClient: client,
  );
  final channel = IOWebSocketChannel(webSocket);
  return _WsClient(channel, client);
}

final class _WsClient {
  new(this._channel, this._httpClient) {
    _iterator = StreamIterator<dynamic>(_channel.stream);
  }

  final IOWebSocketChannel _channel;
  final HttpClient _httpClient;
  late final StreamIterator<dynamic> _iterator;

  Future<WsEnvelope> next() async {
    final hasNext = await _iterator.moveNext().timeout(ioTimeout);
    if (!hasNext) throw StateError('WebSocket closed unexpectedly.');
    return WsEnvelope.decode(_iterator.current as String);
  }

  Future<void> close() async {
    await _iterator.cancel();
    await _channel.sink.close();
    _httpClient.close(force: true);
  }
}
