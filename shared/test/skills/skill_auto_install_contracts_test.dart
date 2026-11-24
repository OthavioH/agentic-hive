import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SkillAutoInstallOutcome', () {
    test('round-trips every wire value', () {
      const expected = <SkillAutoInstallOutcome, String>{
        SkillAutoInstallOutcome.installed: 'installed',
        SkillAutoInstallOutcome.alreadyInstalled: 'already_installed',
        SkillAutoInstallOutcome.skipped: 'skipped',
        SkillAutoInstallOutcome.failed: 'failed',
      };

      for (final entry in expected.entries) {
        final step = SkillAutoInstallStep(outcome: entry.key);
        final json = step.toJson();
        expect(json['outcome'], entry.value);
        expect(SkillAutoInstallStep.fromJson(json), step);
      }
    });

    test('rejects unknown wire values with FormatException', () {
      expect(
        () => SkillAutoInstallStep.fromJson(<String, Object?>{
          'outcome': 'bogus',
        }),
        throwsFormatException,
      );
    });
  });

  group('SkillAutoInstallStep', () {
    test('round-trips paths and message', () {
      const step = SkillAutoInstallStep(
        outcome: SkillAutoInstallOutcome.installed,
        paths: <String>['/tmp/.claude/skills/agentic-hive'],
        message: 'installed',
      );
      final decoded = SkillAutoInstallStep.fromJson(step.toJson());
      expect(decoded, step);
    });

    test('defaults missing paths to empty list and message to null', () {
      final decoded = SkillAutoInstallStep.fromJson(<String, Object?>{
        'outcome': 'already_installed',
      });
      expect(decoded.paths, isEmpty);
      expect(decoded.message, isNull);
    });
  });

  group('SkillAutoInstallNotice', () {
    test('round-trips two harness results with UTC createdAt', () {
      final notice = SkillAutoInstallNotice(
        id: 'notice-1',
        createdAt: DateTime.utc(2026, 11, 24, 12, 30),
        results: const <SkillAutoInstallHarnessResult>[
          SkillAutoInstallHarnessResult(
            harnessId: HarnessId.claudeCode,
            skill: SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.installed,
              paths: <String>['/home/u/.claude/skills/agentic-hive'],
            ),
            mcp: SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.installed,
            ),
          ),
          SkillAutoInstallHarnessResult(
            harnessId: HarnessId.codex,
            skill: SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.skipped,
              message: 'outdated',
            ),
            mcp: SkillAutoInstallStep(
              outcome: SkillAutoInstallOutcome.failed,
              message: 'cli failed',
            ),
          ),
        ],
      );

      final json = notice.toJson();
      final decoded = SkillAutoInstallNotice.fromJson(json);
      expect(decoded, notice);
      expect(decoded.createdAt.isUtc, isTrue);
    });
  });

  group('SkillAutoInstallNoticeResponse', () {
    test('round-trips null notice and populated notice', () {
      const empty = SkillAutoInstallNoticeResponse();
      expect(SkillAutoInstallNoticeResponse.fromJson(empty.toJson()), empty);

      final populated = SkillAutoInstallNoticeResponse(
        notice: SkillAutoInstallNotice(
          id: 'notice-2',
          createdAt: DateTime.utc(2026, 11, 24),
          results: const <SkillAutoInstallHarnessResult>[
            SkillAutoInstallHarnessResult(
              harnessId: HarnessId.geminiCli,
              skill: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.alreadyInstalled,
              ),
              mcp: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.installed,
              ),
            ),
          ],
        ),
      );
      expect(
        SkillAutoInstallNoticeResponse.fromJson(populated.toJson()),
        populated,
      );
    });
  });
}
