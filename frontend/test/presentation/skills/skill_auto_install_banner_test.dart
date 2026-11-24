import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/skill_notice_state.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/skill_auto_install_banner.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: HiveTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  final installedNotice = SkillAutoInstallNotice(
    id: 'n1',
    createdAt: DateTime.utc(2026, 11, 20),
    results: const <SkillAutoInstallHarnessResult>[
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.claudeCode,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.installed,
          paths: <String>['/home/user/.claude/skills/agentic-hive'],
        ),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
      ),
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.codex,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.installed,
          paths: <String>['/home/user/.agents/skills/agentic-hive'],
        ),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
      ),
    ],
  );

  final partialNotice = SkillAutoInstallNotice(
    id: 'n2',
    createdAt: DateTime.utc(2026, 11, 20),
    results: const <SkillAutoInstallHarnessResult>[
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.claudeCode,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.failed,
          message: 'Disk full',
        ),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
      ),
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.codex,
        skill: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.failed),
      ),
    ],
  );

  group('SkillAutoInstallBanner', () {
    testWidgets('installed variant renders success banner, paths, Undo, and '
        'dismiss label', (tester) async {
      var undone = 0;
      var dismissed = 0;
      await tester.pumpWidget(
        _wrap(
          SkillAutoInstallBanner(
            state: SkillNoticeState(notice: installedNotice),
            onUndo: () => undone++,
            onRetry: () {},
            onDismiss: () => dismissed++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final banner = tester.widget<HiveBanner>(find.byType(HiveBanner));
      expect(banner.tone, HiveFeedbackTone.success);
      expect(banner.liveRegion, isTrue);
      expect(banner.dismissSemanticLabel, 'Dismiss notice');
      expect(
        banner.title,
        'Installed the Agentic Hive skill and MCP for Claude Code, Codex.',
      );

      expect(
        find.text('Claude Code: /home/user/.claude/skills/agentic-hive'),
        findsOneWidget,
      );
      expect(
        find.text('Codex: /home/user/.agents/skills/agentic-hive'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('skill_notice_undo')));
      expect(undone, 1);

      await tester.tap(find.bySemanticsLabel('Dismiss notice'));
      expect(dismissed, 1);
    });

    testWidgets('partial variant renders warning banner, failure lines with '
        'fallback, Retry, and no Undo', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _wrap(
          SkillAutoInstallBanner(
            state: SkillNoticeState(notice: partialNotice),
            onUndo: () {},
            onRetry: () => retried++,
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final banner = tester.widget<HiveBanner>(find.byType(HiveBanner));
      expect(banner.tone, HiveFeedbackTone.warning);
      expect(banner.liveRegion, isTrue);
      expect(banner.title, 'Some installs did not finish');

      expect(find.text('Claude Code skill: Disk full'), findsOneWidget);
      expect(find.text('Codex MCP: No details were reported.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('skill_notice_undo')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('skill_notice_retry')),
      );
      expect(retried, 1);
    });

    testWidgets('isWorking sets loading on action button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SkillAutoInstallBanner(
            state: SkillNoticeState(notice: installedNotice, isWorking: true),
            onUndo: () {},
            onRetry: () {},
            onDismiss: () {},
          ),
        ),
      );

      final undo = tester.widget<HiveButton>(
        find.byKey(const ValueKey<String>('skill_notice_undo')),
      );
      expect(undo.loading, isTrue);

      await tester.pumpWidget(
        _wrap(
          SkillAutoInstallBanner(
            state: SkillNoticeState(notice: partialNotice, isWorking: true),
            onUndo: () {},
            onRetry: () {},
            onDismiss: () {},
          ),
        ),
      );

      final retry = tester.widget<HiveButton>(
        find.byKey(const ValueKey<String>('skill_notice_retry')),
      );
      expect(retry.loading, isTrue);
    });
  });
}
