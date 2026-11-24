import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/skill_row_models.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_card.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_skill_row.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'scripted_harness_repository.dart';

Widget _wrap(Widget child, {double textScale = 1.0}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: HiveTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: Builder(
        builder: (context) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.hiveSpacing.space8 * 9,
            ),
            child: child,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('HarnessSkillRow matrix', () {
    testWidgets('Loading (isDisabled true): keeps tag and disables button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HarnessSkillRow(
            harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
            isDisabled: true,
            onInstall: () {},
            onUpdate: () {},
            onRemove: () {},
            onRecheck: () {},
            onRetry: () {},
          ),
        ),
      );

      final badge = tester.widget<HiveBadge>(find.byType(HiveBadge));
      expect(badge.label, 'Skill not installed');
      expect(badge.tone, HiveBadgeTone.neutral);
      expect(badge.icon, HiveIcons.close);

      final button = tester.widget<HiveButton>(
        find.byKey(const ValueKey<String>('harness_skill_install_claude_code')),
      );
      expect(button.label, 'Install');
      expect(button.onPressed, isNull);
    });

    testWidgets('Skill installed: success badge and Remove ghost button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HarnessSkillRow(
            harness: harnessWith(skill: HarnessSkillStatus.installed),
            isDisabled: false,
            onInstall: () {},
            onUpdate: () {},
            onRemove: () {},
            onRecheck: () {},
            onRetry: () {},
          ),
        ),
      );

      final badge = tester.widget<HiveBadge>(find.byType(HiveBadge));
      expect(badge.label, 'Skill installed');
      expect(badge.tone, HiveBadgeTone.success);
      expect(badge.icon, HiveIcons.check);

      final button = tester.widget<HiveButton>(
        find.byKey(const ValueKey<String>('harness_skill_remove_claude_code')),
      );
      expect(button.label, 'Remove');
      expect(button.variant, HiveButtonVariant.ghost);
      expect(button.size, HiveButtonSize.small);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Not installed: neutral badge and Install button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HarnessSkillRow(
            harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
            isDisabled: false,
            onInstall: () {},
            onUpdate: () {},
            onRemove: () {},
            onRecheck: () {},
            onRetry: () {},
          ),
        ),
      );

      final badge = tester.widget<HiveBadge>(find.byType(HiveBadge));
      expect(badge.label, 'Skill not installed');
      expect(badge.tone, HiveBadgeTone.neutral);
      expect(badge.icon, HiveIcons.close);

      final button = tester.widget<HiveButton>(
        find.byKey(const ValueKey<String>('harness_skill_install_claude_code')),
      );
      expect(button.label, 'Install');
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Outdated: warning badge and Update button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HarnessSkillRow(
            harness: harnessWith(skill: HarnessSkillStatus.outdated),
            isDisabled: false,
            onInstall: () {},
            onUpdate: () {},
            onRemove: () {},
            onRecheck: () {},
            onRetry: () {},
          ),
        ),
      );

      final badge = tester.widget<HiveBadge>(find.byType(HiveBadge));
      expect(badge.label, 'Skill outdated');
      expect(badge.tone, HiveBadgeTone.warning);
      expect(badge.icon, HiveIcons.alert);

      final button = tester.widget<HiveButton>(
        find.byKey(const ValueKey<String>('harness_skill_update_claude_code')),
      );
      expect(button.label, 'Update');
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Modified: warning badge and Update button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HarnessSkillRow(
            harness: harnessWith(skill: HarnessSkillStatus.modified),
            isDisabled: false,
            onInstall: () {},
            onUpdate: () {},
            onRemove: () {},
            onRecheck: () {},
            onRetry: () {},
          ),
        ),
      );

      final badge = tester.widget<HiveBadge>(find.byType(HiveBadge));
      expect(badge.label, 'Skill modified');
      expect(badge.tone, HiveBadgeTone.warning);
      expect(badge.icon, HiveIcons.alert);

      final button = tester.widget<HiveButton>(
        find.byKey(const ValueKey<String>('harness_skill_update_claude_code')),
      );
      expect(button.label, 'Update');
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Conflict: danger badge, no action, and exact explanation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HarnessSkillRow(
            harness: harnessWith(skill: HarnessSkillStatus.conflict),
            isDisabled: false,
            onInstall: () {},
            onUpdate: () {},
            onRemove: () {},
            onRecheck: () {},
            onRetry: () {},
          ),
        ),
      );

      final badge = tester.widget<HiveBadge>(find.byType(HiveBadge));
      expect(badge.label, 'Skill conflict');
      expect(badge.tone, HiveBadgeTone.danger);
      expect(badge.icon, HiveIcons.alert);

      expect(find.byType(HiveButton), findsNothing);
      expect(
        find.text(
          'A skill named agentic-hive already exists here and was not '
          'installed by Agentic Hive.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Unknown: neutral badge, Retry calls onRecheck, shows message',
      (tester) async {
        var rechecked = 0;
        await tester.pumpWidget(
          _wrap(
            HarnessSkillRow(
              harness: harnessWith(
                skill: HarnessSkillStatus.unknown,
                skillMessage: 'Could not read skill folder.',
              ),
              isDisabled: false,
              onInstall: () {},
              onUpdate: () {},
              onRemove: () {},
              onRecheck: () => rechecked++,
              onRetry: () {},
            ),
          ),
        );

        final badge = tester.widget<HiveBadge>(find.byType(HiveBadge));
        expect(badge.label, 'Skill status unknown');
        expect(badge.tone, HiveBadgeTone.neutral);
        expect(badge.icon, HiveIcons.info);

        expect(find.text('Could not read skill folder.'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('harness_skill_retry_claude_code')),
        );
        expect(rechecked, 1);
      },
    );

    testWidgets(
      'Busy: shows loading button with progressive label, keeps focusable '
      'no-op callback, and ignores activation',
      (tester) async {
        var installs = 0;
        await tester.pumpWidget(
          _wrap(
            HarnessSkillRow(
              harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
              isDisabled: false,
              busyAction: SkillRowAction.install,
              onInstall: () => installs++,
              onUpdate: () {},
              onRemove: () {},
              onRecheck: () {},
              onRetry: () {},
            ),
          ),
        );

        final buttonFinder = find.byKey(
          const ValueKey<String>('harness_skill_install_claude_code'),
        );
        final button = tester.widget<HiveButton>(buttonFinder);
        expect(button.loading, isTrue);
        expect(button.label, 'Installing…');
        expect(button.onPressed, isNotNull);

        await tester.tap(buttonFinder);
        await tester.pump();
        expect(installs, 0);
      },
    );

    testWidgets('Error: renders danger live-region banner with Retry', (
      tester,
    ) async {
      var retried = 0;
      await tester.pumpWidget(
        _wrap(
          HarnessSkillRow(
            harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
            isDisabled: false,
            error: const SkillRowError(
              failure: BackendFailure('Disk full'),
              action: SkillRowAction.install,
            ),
            onInstall: () {},
            onUpdate: () {},
            onRemove: () {},
            onRecheck: () {},
            onRetry: () => retried++,
          ),
        ),
      );

      final banner = tester.widget<HiveBanner>(
        find.byKey(const ValueKey<String>('harness_skill_error_claude_code')),
      );
      expect(banner.tone, HiveFeedbackTone.danger);
      expect(banner.liveRegion, isTrue);
      expect(banner.title, 'The skill action failed');
      expect(banner.message, 'Disk full');

      final retryFinder = find.byKey(
        const ValueKey<String>('harness_skill_retry_claude_code'),
      );
      expect(retryFinder, findsOneWidget);
      await tester.tap(retryFinder);
      expect(retried, 1);
    });

    testWidgets('MCP missing: renders warning banner when skill present and '
        'MCP notInstalled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HarnessSkillRow(
            harness: harnessWith(
              skill: HarnessSkillStatus.installed,
              mcp: HarnessMcpStatus.notInstalled,
            ),
            isDisabled: false,
            onInstall: () {},
            onUpdate: () {},
            onRemove: () {},
            onRecheck: () {},
            onRetry: () {},
          ),
        ),
      );

      final banner = tester.widget<HiveBanner>(
        find.byKey(
          const ValueKey<String>('harness_skill_mcp_missing_claude_code'),
        ),
      );
      expect(banner.tone, HiveFeedbackTone.warning);
      expect(banner.liveRegion, isTrue);
      expect(banner.title, 'The skill needs the Hive MCP server.');
      expect(banner.onDismiss, isNull);
      expect(banner.actions, isEmpty);
    });

    testWidgets(
      'No skill row when skillStatus is null and MCP section remains',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            HarnessCard(
              harness: harnessWith(),
              isRefreshing: false,
              isGlobalRefreshing: false,
              onRecheck: () {},
              onCopyPath: (_) {},
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('harness_skill_row_claude_code')),
          findsNothing,
        );
        expect(find.textContaining('Skill'), findsNothing);
        expect(find.text('MCP installed'), findsOneWidget);
      },
    );

    testWidgets(
      'Semantics liveRegion, labeled tap targets, and textScale 2.0',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _wrap(
            HarnessSkillRow(
              harness: harnessWith(
                skill: HarnessSkillStatus.installed,
                mcp: HarnessMcpStatus.notInstalled,
              ),
              isDisabled: false,
              error: const SkillRowError(
                failure: BackendFailure('Failed to remove'),
                action: SkillRowAction.remove,
              ),
              onInstall: () {},
              onUpdate: () {},
              onRemove: () {},
              onRecheck: () {},
              onRetry: () {},
            ),
            textScale: 2,
          ),
        );

        expect(tester.takeException(), isNull);
        final liveSemantics = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        );
        expect(liveSemantics, findsAtLeastNWidgets(1));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      },
    );
  });
}
