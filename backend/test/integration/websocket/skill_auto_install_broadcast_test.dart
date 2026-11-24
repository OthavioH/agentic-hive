import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_backend/src/ws/ws_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'support/ws_harness.dart';

void main() {
  late Directory dir;
  late HttpServer httpServer;
  late ConnectionRegistry registry;
  late StreamController<SkillAutoInstallNotice> controller;
  late WsGateway gateway;
  late String socketPath;
  final clients = <WsTestClient>[];

  setUp(() async {
    dir = await createShortTempDir();
    socketPath = p.join(dir.path, 'gw-skill-auto.sock');
    registry = ConnectionRegistry();
    controller = StreamController<SkillAutoInstallNotice>.broadcast();
    gateway = WsGateway(
      registry: registry,
      pingInterval: const Duration(seconds: 20),
      serverVersion: 'test',
      skillAutoInstalls: controller.stream,
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
    await controller.close();
    await httpServer.close(force: true);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  test(
    'broadcasts skills.auto_installed to connected clients and stops on close',
    () async {
      final c1 = await WsTestClient.connect(socketPath);
      final c2 = await WsTestClient.connect(socketPath);
      clients
        ..add(c1)
        ..add(c2);

      await c1.next(); // server.hello
      await c2.next(); // server.hello

      final notice = SkillAutoInstallNotice(
        id: 'notice-ws-1',
        createdAt: DateTime.utc(2026, 11, 24, 12),
        results: const <SkillAutoInstallHarnessResult>[
          SkillAutoInstallHarnessResult(
            harnessId: HarnessId.claudeCode,
            skill: SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.installed,
              paths: <String>['/tmp/.claude/skills/agentic-hive'],
            ),
            mcp: SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.installed,
            ),
          ),
        ],
      );

      controller.add(notice);

      final f1 = await c1.next();
      final f2 = await c2.next();
      expect(f1.type, WsMessageType.skillsAutoInstalled);
      expect(f2.type, WsMessageType.skillsAutoInstalled);
      expect(SkillAutoInstallNoticePayload.fromJson(f1.payload).notice, notice);
      expect(SkillAutoInstallNoticePayload.fromJson(f2.payload).notice, notice);

      await gateway.close();
      controller.add(notice);
      await expectLater(
        c1.next().timeout(const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
