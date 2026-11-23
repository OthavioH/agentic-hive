import 'dart:io';

import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_backend/src/ws/ws_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'support/ws_harness.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 20, 21);

  late Directory dir;
  late HttpServer httpServer;
  late ConnectionRegistry registry;
  late DefaultHarnessService harnessService;
  late WsGateway gateway;
  late _FakeDetector claude;
  late String socketPath;
  final clients = <WsTestClient>[];

  setUp(() async {
    dir = await createShortTempDir();
    socketPath = p.join(dir.path, 'gw-harness.sock');
    registry = ConnectionRegistry();
    claude = _FakeDetector(
      HarnessId.claudeCode,
      HarnessInfo(
        id: HarnessId.claudeCode,
        displayName: 'Claude Code',
        status: HarnessStatus.ready,
        version: '2.1.0',
        executablePath: '/usr/bin/claude',
        checkedAt: t0,
      ),
    );
    harnessService = DefaultHarnessService(
      detectors: [claude],
      now: () => t0.add(const Duration(seconds: 5)),
    );
    gateway = WsGateway(
      registry: registry,
      pingInterval: const Duration(seconds: 20),
      serverVersion: 'test',
      harnessStatusUpdates: harnessService.statusUpdates,
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
    await gateway.close();
    await harnessService.dispose();
    await httpServer.close(force: true);
    await deleteDir(dir);
  });

  test('WsGateway broadcasts harnessStatusUpdated for refreshOne and '
      'reportAuthError', () async {
    final client = await WsTestClient.connect(socketPath);
    clients.add(client);
    expect((await client.next()).type, WsMessageType.serverHello);

    await harnessService.refreshOne(HarnessId.claudeCode);
    final refreshEnvelope = await client.next();
    expect(refreshEnvelope.type, WsMessageType.harnessStatusUpdated);
    final refreshPayload = HarnessStatusUpdatedPayload.fromJson(
      refreshEnvelope.payload,
    );
    expect(refreshPayload.harness.id, HarnessId.claudeCode);
    expect(refreshPayload.harness.status, HarnessStatus.ready);
    expect(refreshPayload.harness.version, '2.1.0');

    harnessService.reportAuthError(HarnessId.claudeCode);
    final authEnvelope = await client.next();
    expect(authEnvelope.type, WsMessageType.harnessStatusUpdated);
    final authPayload = HarnessStatusUpdatedPayload.fromJson(
      authEnvelope.payload,
    );
    expect(authPayload.harness.id, HarnessId.claudeCode);
    expect(authPayload.harness.status, HarnessStatus.authError);
    expect(authPayload.harness.version, '2.1.0');
  });
}

final class _FakeDetector implements HarnessDetector {
  new(this.id, this.next);

  @override
  final HarnessId id;

  HarnessInfo next;

  @override
  void setExecutableOverride(String? path) {}

  @override
  Future<HarnessInfo> detect() async => next;
}
