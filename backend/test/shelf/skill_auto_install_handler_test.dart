import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/api/skills/skill_auto_install_handler.dart';
import 'package:agentic_hive_backend/src/domain/skills/skill_auto_install_service.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

// Routes:
// - GET    /api/v1/skills/auto-install/notice -> 200 SkillAutoInstallNoticeResponse
// - DELETE /api/v1/skills/auto-install/notice -> 204 (idempotent)

void main() {
  late _FakeSkillAutoInstallService service;
  late Handler handler;

  setUp(() {
    service = _FakeSkillAutoInstallService();
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        version: '0.1.0',
        dataDir: '/tmp',
        startedAt: DateTime.utc(2026, 11, 24),
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true),
        ),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) async => Response(404),
      skillAutoInstallHandler: SkillAutoInstallHandler(service),
    );
  });

  test('GET returns 200 with notice: null when none is pending', () async {
    final response = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/v1/skills/auto-install/notice'),
      ),
    );
    expect(response.statusCode, 200);
    final decoded = SkillAutoInstallNoticeResponse.fromJson(
      jsonDecode(await response.readAsString()) as JsonMap,
    );
    expect(decoded.notice, isNull);
  });

  test(
    'GET returns 200 with pending notice, DELETE clears it idempotently',
    () async {
      final notice = SkillAutoInstallNotice(
        id: 'n-1',
        createdAt: DateTime.utc(2026, 11, 24, 12),
        results: const <SkillAutoInstallHarnessResult>[
          SkillAutoInstallHarnessResult(
            harnessId: HarnessId.claudeCode,
            skill: SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.installed,
              paths: <String>['/home/u/.claude/skills/agentic-hive'],
            ),
            mcp: SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.failed,
              message: 'cli error',
            ),
          ),
        ],
      );
      service.pendingNotice = notice;

      final getRes = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/v1/skills/auto-install/notice'),
        ),
      );
      expect(getRes.statusCode, 200);
      final decoded = SkillAutoInstallNoticeResponse.fromJson(
        jsonDecode(await getRes.readAsString()) as JsonMap,
      );
      expect(decoded.notice, notice);

      final delRes = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/v1/skills/auto-install/notice'),
        ),
      );
      expect(delRes.statusCode, 204);

      final afterDel = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/v1/skills/auto-install/notice'),
        ),
      );
      expect(afterDel.statusCode, 200);
      expect(
        SkillAutoInstallNoticeResponse.fromJson(
          jsonDecode(await afterDel.readAsString()) as JsonMap,
        ).notice,
        isNull,
      );

      final delAgain = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/v1/skills/auto-install/notice'),
        ),
      );
      expect(delAgain.statusCode, 204);
    },
  );
}

final class _FakeSkillAutoInstallService implements SkillAutoInstallService {
  @override
  SkillAutoInstallNotice? pendingNotice;

  @override
  Stream<SkillAutoInstallNotice> get notices => const Stream.empty();

  @override
  bool get isStarted => true;

  @override
  void start() {}

  @override
  void dismissNotice({String? noticeId}) {
    if (noticeId == null || pendingNotice?.id == noticeId) {
      pendingNotice = null;
    }
  }

  @override
  Future<void> idle() async {}

  @override
  Future<void> dispose() async {}
}
