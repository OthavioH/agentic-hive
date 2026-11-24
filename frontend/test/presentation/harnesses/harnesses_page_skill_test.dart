import 'package:agentic_hive_frontend/core/backend/app_version_provider.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/pages/harnesses_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../skills/memory_outdated_banner_store.dart';
import 'scripted_harness_repository.dart';

List<Override> _pageOverrides({
  required ScriptedHarnessRepository repo,
  required MemoryOutdatedBannerStore store,
  String? appVersion = '1.2.3',
}) => <Override>[
  harnessRepositoryProvider.overrideWithValue(repo),
  outdatedBannerStoreProvider.overrideWithValue(store),
  appVersionProvider.overrideWithValue(appVersion),
];

Widget _buildPage() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: HiveTheme.dark(),
  home: const Scaffold(body: HarnessesPage()),
);

void main() {
  const desktopSize = Size(1280, 900);

  Future<void> configureDesktop(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }

  group('HarnessesPage skill flows', () {
    testWidgets(
      'Install calls installSkill(overwriteModified: false) and shows toast',
      (tester) async {
        await configureDesktop(tester);
        final claude = harnessWith(skill: HarnessSkillStatus.notInstalled);
        final repo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[claude])
          ..installSkillResult = Success(
            claude.copyWith(skillStatus: HarnessSkillStatus.installed),
          );
        addTearDown(repo.dispose);
        final store = MemoryOutdatedBannerStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _pageOverrides(repo: repo, store: store),
            child: _buildPage(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('harness_skill_install_claude_code'),
          ),
        );
        await tester.pump();
        await tester.pump(HiveMotionTokens.standard.medium);

        expect(
          repo.installSkillCalls,
          <({HarnessId id, bool overwriteModified})>[
            (id: HarnessId.claudeCode, overwriteModified: false),
          ],
        );
        expect(
          find.text('Installed the skill for Claude Code'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Remove opens destructive confirm dialog with Cancel focused; cancel '
      'does not call API, confirm removes and toasts',
      (tester) async {
        await configureDesktop(tester);
        final claude = harnessWith(skill: HarnessSkillStatus.installed);
        final repo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[claude])
          ..removeSkillResult = Success(
            claude.copyWith(skillStatus: HarnessSkillStatus.notInstalled),
          );
        addTearDown(repo.dispose);
        final store = MemoryOutdatedBannerStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _pageOverrides(repo: repo, store: store),
            child: _buildPage(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('harness_skill_remove_claude_code'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HiveConfirmDialog), findsOneWidget);
        expect(find.text('Remove the skill from Claude Code?'), findsOneWidget);

        // Cancel button must hold primary focus.
        final cancelButton = find.widgetWithText(HiveButton, 'Cancel');
        final focusedButton = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<HiveButton>();
        expect(focusedButton?.label, 'Cancel');

        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
        expect(repo.removeSkillCalls, isEmpty);

        // Open again and confirm.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('harness_skill_remove_claude_code'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(HiveConfirmDialog),
            matching: find.widgetWithText(HiveButton, 'Remove'),
          ),
        );
        await tester.pump();
        await tester.pump(HiveMotionTokens.standard.medium);

        expect(repo.removeSkillCalls, <HarnessId>[HarnessId.claudeCode]);
        expect(find.text('Removed the skill from Claude Code'), findsOneWidget);
      },
    );

    testWidgets(
      'Update on modified opens overwrite confirm dialog with Cancel focused '
      'and sends overwriteModified: true',
      (tester) async {
        await configureDesktop(tester);
        final claude = harnessWith(skill: HarnessSkillStatus.modified);
        final repo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[claude])
          ..installSkillResult = Success(
            claude.copyWith(skillStatus: HarnessSkillStatus.installed),
          );
        addTearDown(repo.dispose);
        final store = MemoryOutdatedBannerStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _pageOverrides(repo: repo, store: store),
            child: _buildPage(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('harness_skill_update_claude_code'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Replace your edited skill?'), findsOneWidget);
        final focusedButton = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<HiveButton>();
        expect(focusedButton?.label, 'Cancel');

        await tester.tap(find.widgetWithText(HiveButton, 'Replace'));
        await tester.pump();
        await tester.pump(HiveMotionTokens.standard.medium);

        expect(
          repo.installSkillCalls,
          <({HarnessId id, bool overwriteModified})>[
            (id: HarnessId.claudeCode, overwriteModified: true),
          ],
        );
      },
    );

    testWidgets(
      'Update on outdated skips dialog and sends overwriteModified: false',
      (tester) async {
        await configureDesktop(tester);
        final claude = harnessWith(skill: HarnessSkillStatus.outdated);
        final repo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[claude])
          ..installSkillResult = Success(
            claude.copyWith(skillStatus: HarnessSkillStatus.installed),
          );
        addTearDown(repo.dispose);
        final store = MemoryOutdatedBannerStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _pageOverrides(repo: repo, store: store),
            child: _buildPage(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('harness_skill_update_claude_code'),
          ),
        );
        await tester.pump();
        await tester.pump(HiveMotionTokens.standard.medium);

        expect(find.byType(HiveConfirmDialog), findsNothing);
        expect(
          repo.installSkillCalls,
          <({HarnessId id, bool overwriteModified})>[
            (id: HarnessId.claudeCode, overwriteModified: false),
          ],
        );
      },
    );

    testWidgets(
      'Failure shows inline banner and Retry repeats confirmed overwrite '
      'without another dialog',
      (tester) async {
        await configureDesktop(tester);
        final claude = harnessWith(skill: HarnessSkillStatus.modified);
        final repo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[claude])
          ..installSkillResult = const FailureResult<HarnessInfo>(
            BackendFailure('Disk full'),
          );
        addTearDown(repo.dispose);
        final store = MemoryOutdatedBannerStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _pageOverrides(repo: repo, store: store),
            child: _buildPage(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('harness_skill_update_claude_code'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(HiveButton, 'Replace'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('harness_skill_error_claude_code')),
          findsOneWidget,
        );
        expect(find.text('Disk full'), findsOneWidget);
        expect(find.byType(HiveToast), findsNothing);

        repo.installSkillResult = Success(
          claude.copyWith(skillStatus: HarnessSkillStatus.installed),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('harness_skill_retry_claude_code')),
        );
        await tester.pump();
        await tester.pump(HiveMotionTokens.standard.medium);

        expect(find.byType(HiveConfirmDialog), findsNothing);
        expect(
          repo.installSkillCalls,
          <({HarnessId id, bool overwriteModified})>[
            (id: HarnessId.claudeCode, overwriteModified: true),
            (id: HarnessId.claudeCode, overwriteModified: true),
          ],
        );
      },
    );

    testWidgets('Retry on unknown calls refreshHarness', (tester) async {
      await configureDesktop(tester);
      final claude = harnessWith(skill: HarnessSkillStatus.unknown);
      final repo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[claude])
        ..refreshOneResult = Success(
          claude.copyWith(skillStatus: HarnessSkillStatus.installed),
        );
      addTearDown(repo.dispose);
      final store = MemoryOutdatedBannerStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _pageOverrides(repo: repo, store: store),
          child: _buildPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('harness_skill_retry_claude_code')),
      );
      await tester.pumpAndSettle();

      expect(repo.refreshHarnessCalls, <HarnessId>[HarnessId.claudeCode]);
    });

    testWidgets('Opening HarnessesPage acknowledges outdated version', (
      tester,
    ) async {
      await configureDesktop(tester);
      final repo = ScriptedHarnessRepository();
      addTearDown(repo.dispose);
      final store = MemoryOutdatedBannerStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _pageOverrides(
            repo: repo,
            store: store,
            appVersion: '2.5.0',
          ),
          child: _buildPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.savedVersions, <String>['2.5.0']);
      expect(store.acknowledgedVersion, '2.5.0');
    });

    testWidgets('Empty and load-error states render no skill UI', (
      tester,
    ) async {
      await configureDesktop(tester);
      final repo = ScriptedHarnessRepository()
        ..getResult = const FailureResult<List<HarnessInfo>>(
          NetworkFailure('offline'),
        );
      addTearDown(repo.dispose);
      final store = MemoryOutdatedBannerStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _pageOverrides(repo: repo, store: store),
          child: _buildPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('harnesses_retry_button')),
        findsOneWidget,
      );
      expect(find.textContaining('Skill'), findsNothing);

      repo.getResult = const Success<List<HarnessInfo>>(<HarnessInfo>[]);
      await tester.tap(
        find.byKey(const ValueKey<String>('harnesses_retry_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No harnesses detected'), findsOneWidget);
      expect(find.textContaining('Skill'), findsNothing);
    });
  });
}
