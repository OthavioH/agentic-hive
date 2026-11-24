import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SkillAutoInstallNoticePayload', () {
    test('round-trips notice payload and matches WsMessageType constant', () {
      expect(WsMessageType.skillsAutoInstalled, 'skills.auto_installed');

      final payload = SkillAutoInstallNoticePayload(
        notice: SkillAutoInstallNotice(
          id: 'notice-ws-1',
          createdAt: DateTime.utc(2026, 11, 24, 8, 15),
          results: const <SkillAutoInstallHarnessResult>[
            SkillAutoInstallHarnessResult(
              harnessId: HarnessId.claudeCode,
              skill: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.installed,
                paths: <String>['/tmp/skills/agentic-hive'],
              ),
              mcp: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.installed,
              ),
            ),
          ],
        ),
      );

      final decoded = SkillAutoInstallNoticePayload.fromJson(payload.toJson());
      expect(decoded, payload);
    });
  });
}
