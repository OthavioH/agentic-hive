import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/app_version_provider.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/settings/file_picker_data_source.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/skill_row_models.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_card.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_skill_row.dart';
import 'package:agentic_hive_frontend/presentation/settings/pages/settings_page.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/skill_notice_state.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/outdated_tools_banner.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/skill_auto_install_banner.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../skills/memory_outdated_banner_store.dart';
import 'scripted_harness_repository.dart';

Widget _appWrap(
  Widget child, {
  double textScale = 1.0,
  bool disableAnimations = false,
  double? maxWidth,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: HiveTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        child: maxWidth == null
            ? child
            : SizedBox(width: maxWidth, child: child),
      ),
    ),
  ),
);

final class _FakeSettingsRepo implements SettingsRepository {
  @override
  Future<Result<AppSettings>> getSettings() async => const Success(
    AppSettings(
      effectiveAgentsDir: '/home/user/.agents/agents',
      defaultAgentsDir: '/home/user/.agents/agents',
    ),
  );

  @override
  Future<Result<AppSettings>> updateSettings(
    UpdateSettingsRequest request,
  ) async => throw UnimplementedError();

  @override
  Stream<AppSettings> watchSettingsUpdates() => const Stream.empty();
}

final class _FakeThemeStore implements ThemePreferenceStore {
  @override
  Future<AppThemePreference> load() async => AppThemePreference.dark;

  @override
  Future<void> save(AppThemePreference preference) async {}
}

final class _FakePicker implements FilePickerDataSource {
  @override
  Future<String?> pickDirectory({String? initialDirectory}) async => null;

  @override
  Future<String?> pickFile({String? initialDirectory}) async => null;
}

void main() {
  group('5.2 Skill UI styling states', () {
    testWidgets('Variant test: badge tones, button variants/sizes, no danger', (
      tester,
    ) async {
      final expected =
          <
            HarnessSkillStatus,
            ({
              HiveBadgeTone tone,
              String? buttonKey,
              HiveButtonVariant? variant,
            })
          >{
            HarnessSkillStatus.installed: (
              tone: HiveBadgeTone.success,
              buttonKey: 'harness_skill_remove_claude_code',
              variant: HiveButtonVariant.ghost,
            ),
            HarnessSkillStatus.notInstalled: (
              tone: HiveBadgeTone.neutral,
              buttonKey: 'harness_skill_install_claude_code',
              variant: HiveButtonVariant.secondary,
            ),
            HarnessSkillStatus.outdated: (
              tone: HiveBadgeTone.warning,
              buttonKey: 'harness_skill_update_claude_code',
              variant: HiveButtonVariant.secondary,
            ),
            HarnessSkillStatus.modified: (
              tone: HiveBadgeTone.warning,
              buttonKey: 'harness_skill_update_claude_code',
              variant: HiveButtonVariant.secondary,
            ),
            HarnessSkillStatus.conflict: (
              tone: HiveBadgeTone.danger,
              buttonKey: null,
              variant: null,
            ),
            HarnessSkillStatus.unknown: (
              tone: HiveBadgeTone.neutral,
              buttonKey: 'harness_skill_retry_claude_code',
              variant: HiveButtonVariant.secondary,
            ),
          };

      for (final entry in expected.entries) {
        await tester.pumpWidget(
          _appWrap(
            HarnessSkillRow(
              harness: harnessWith(skill: entry.key),
              isDisabled: false,
              error: const SkillRowError(
                failure: BackendFailure('err'),
                action: SkillRowAction.install,
              ),
              onInstall: () {},
              onUpdate: () {},
              onRemove: () {},
              onRecheck: () {},
              onRetry: () {},
            ),
          ),
        );

        final badge = tester.widget<HiveBadge>(find.byType(HiveBadge));
        expect(badge.tone, entry.value.tone, reason: '${entry.key}');

        if (entry.value.buttonKey != null) {
          final button = tester.widget<HiveButton>(
            find.byKey(ValueKey<String>(entry.value.buttonKey!)).first,
          );
          expect(button.variant, entry.value.variant, reason: '${entry.key}');
          expect(button.size, HiveButtonSize.small, reason: '${entry.key}');
        }

        for (final button in tester.widgetList<HiveButton>(
          find.byType(HiveButton),
        )) {
          expect(button.variant, isNot(HiveButtonVariant.primary));
          expect(button.variant, isNot(HiveButtonVariant.danger));
          expect(button.size, HiveButtonSize.small);
        }
      }
    });

    testWidgets(
      'Conflict explanation uses onSurface; unknown skillMessage uses '
      'onSurfaceMuted',
      (tester) async {
        await tester.pumpWidget(
          _appWrap(
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
        final conflictText = tester.widget<Text>(
          find.text(
            'A skill named agentic-hive already exists here and was not '
            'installed by Agentic Hive.',
          ),
        );
        expect(conflictText.style?.color, HiveColors.dark.onSurface);

        await tester.pumpWidget(
          _appWrap(
            HarnessSkillRow(
              harness: harnessWith(
                skill: HarnessSkillStatus.unknown,
                skillMessage: 'Permission denied',
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
        final unknownText = tester.widget<Text>(find.text('Permission denied'));
        expect(unknownText.style?.color, HiveColors.dark.onSurfaceMuted);
      },
    );

    testWidgets(
      'Focus order inside HarnessCard, Enter activation, and disabled skip',
      (tester) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        var updated = 0;

        await tester.pumpWidget(
          _appWrap(
            HarnessCard(
              harness: harnessWith(
                skill: HarnessSkillStatus.outdated,
                mcp: HarnessMcpStatus.notInstalled,
              ),
              isRefreshing: false,
              isGlobalRefreshing: false,
              onRecheck: () {},
              onCopyPath: (_) {},
              onInstallMcp: () {},
              onUpdateSkill: () => updated++,
            ),
          ),
        );
        await tester.pump();

        String? focusedKeyValue() {
          final context = FocusManager.instance.primaryFocus?.context;
          if (context == null) return null;
          String? found;
          context.visitAncestorElements((element) {
            final key = element.widget.key;
            if (key is ValueKey<String> && key.value.startsWith('harness_')) {
              found = key.value;
              return false;
            }
            return true;
          });
          return found;
        }

        final visited = <String?>[];
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          visited.add(focusedKeyValue());
        }

        expect(visited, <String>[
          'harness_recheck_claude_code',
          'harness_copy_claude_code',
          'harness_mcp_install_claude_code',
          'harness_skill_update_claude_code',
        ]);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(updated, 1);

        // Disabled (busy) error sibling is skipped on Tab.
        await tester.pumpWidget(
          _appWrap(
            HarnessCard(
              harness: harnessWith(
                skill: HarnessSkillStatus.outdated,
                mcp: HarnessMcpStatus.notInstalled,
              ),
              isRefreshing: false,
              isGlobalRefreshing: false,
              skillAction: SkillRowAction.update,
              skillError: const SkillRowError(
                failure: BackendFailure('Previous error'),
                action: SkillRowAction.update,
              ),
              onRecheck: () {},
              onCopyPath: (_) {},
              onInstallMcp: () {},
              onUpdateSkill: () {},
              onRetrySkill: () {},
            ),
          ),
        );
        await tester.pump();

        final retryButton = tester.widget<HiveButton>(
          find.byKey(const ValueKey<String>('harness_skill_retry_claude_code')),
        );
        expect(retryButton.onPressed, isNull);
        expect(retryButton.loading, isFalse);

        final visitedWhileBusy = <String?>[];
        for (var i = 0; i < 5; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          visitedWhileBusy.add(focusedKeyValue());
        }
        expect(
          visitedWhileBusy,
          isNot(contains('harness_skill_retry_claude_code')),
        );
      },
    );

    testWidgets(
      'Busy: only acting button is loading, siblings have onPressed == null, '
      'focus stays on acting button',
      (tester) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _appWrap(
            HarnessSkillRow(
              harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
              isDisabled: false,
              busyAction: SkillRowAction.install,
              error: const SkillRowError(
                failure: BackendFailure('err'),
                action: SkillRowAction.install,
              ),
              onInstall: () {},
              onUpdate: () {},
              onRemove: () {},
              onRecheck: () {},
              onRetry: () {},
            ),
          ),
        );

        final installBtn = tester.widget<HiveButton>(
          find.byKey(
            const ValueKey<String>('harness_skill_install_claude_code'),
          ),
        );
        final retryBtn = tester.widget<HiveButton>(
          find.byKey(const ValueKey<String>('harness_skill_retry_claude_code')),
        );
        expect(installBtn.loading, isTrue);
        expect(retryBtn.loading, isFalse);
        expect(retryBtn.onPressed, isNull);

        // Focus remains on the acting button when it transitions to busy.
        await tester.pumpWidget(
          _appWrap(
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
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<HiveButton>()
              ?.key,
          const ValueKey<String>('harness_skill_install_claude_code'),
        );

        await tester.pumpWidget(
          _appWrap(
            HarnessSkillRow(
              harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
              isDisabled: false,
              busyAction: SkillRowAction.install,
              onInstall: () {},
              onUpdate: () {},
              onRemove: () {},
              onRecheck: () {},
              onRetry: () {},
            ),
          ),
        );
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<HiveButton>()
              ?.key,
          const ValueKey<String>('harness_skill_install_claude_code'),
        );
      },
    );

    testWidgets(
      'Reduced motion: banners render after 1 pump without FluxFade when '
      'disableAnimations is true, and wrap with FluxFade when false',
      (tester) async {
        final notice = SkillAutoInstallNotice(
          id: 'n1',
          createdAt: DateTime.utc(2026, 11, 20),
          results: const <SkillAutoInstallHarnessResult>[
            SkillAutoInstallHarnessResult(
              harnessId: HarnessId.claudeCode,
              skill: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.installed,
                paths: <String>['/home/user/.claude/skills/agentic-hive'],
              ),
              mcp: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.installed,
              ),
            ),
          ],
        );

        final fluxFadeFinder = find.byWidgetPredicate(
          (w) => '${w.runtimeType}' == 'FluxFade',
        );

        // First-run notice with animations disabled.
        await tester.pumpWidget(
          _appWrap(
            SkillAutoInstallBanner(
              state: SkillNoticeState(notice: notice),
              onUndo: () {},
              onRetry: () {},
              onDismiss: () {},
            ),
            disableAnimations: true,
          ),
        );
        expect(find.byType(HiveSlideIn), findsOneWidget);
        expect(fluxFadeFinder, findsNothing);
        expect(tester.getSize(find.byType(HiveBanner)).height, greaterThan(0));

        // First-run notice with animations enabled.
        await tester.pumpWidget(
          _appWrap(
            SkillAutoInstallBanner(
              state: SkillNoticeState(notice: notice),
              onUndo: () {},
              onRetry: () {},
              onDismiss: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(HiveSlideIn), findsOneWidget);
        expect(fluxFadeFinder, findsOneWidget);
        await tester.pumpAndSettle();

        // Outdated banner with animations disabled.
        final harnessRepo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.outdated),
          ]);
        addTearDown(harnessRepo.dispose);
        final store = MemoryOutdatedBannerStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              harnessRepositoryProvider.overrideWithValue(harnessRepo),
              outdatedBannerStoreProvider.overrideWithValue(store),
              appVersionProvider.overrideWithValue('1.0.0'),
            ],
            child: _appWrap(
              const OutdatedToolsBanner(),
              disableAnimations: true,
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('outdated_tools_banner')),
          findsOneWidget,
        );
        expect(find.byType(HiveSlideIn), findsOneWidget);
        expect(fluxFadeFinder, findsNothing);

        // Outdated banner with animations enabled.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              harnessRepositoryProvider.overrideWithValue(harnessRepo),
              outdatedBannerStoreProvider.overrideWithValue(store),
              appVersionProvider.overrideWithValue('1.0.0'),
            ],
            child: _appWrap(const OutdatedToolsBanner()),
          ),
        );
        await tester.pump();
        expect(find.byType(HiveSlideIn), findsOneWidget);
        expect(fluxFadeFinder, findsOneWidget);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Large text (2x at 1280x720 and 480-wide card): all 11 card states, '
      'both banners, and settings have no overflow and keep buttons inside '
      'card bounds',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final cardCases =
            <
              ({
                String name,
                HarnessInfo harness,
                bool isRefreshing,
                SkillRowAction? busy,
                SkillRowError? error,
              })
            >[
              (
                name: 'installed',
                harness: harnessWith(skill: HarnessSkillStatus.installed),
                isRefreshing: false,
                busy: null,
                error: null,
              ),
              (
                name: 'notInstalled',
                harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
                isRefreshing: false,
                busy: null,
                error: null,
              ),
              (
                name: 'outdated',
                harness: harnessWith(skill: HarnessSkillStatus.outdated),
                isRefreshing: false,
                busy: null,
                error: null,
              ),
              (
                name: 'modified',
                harness: harnessWith(skill: HarnessSkillStatus.modified),
                isRefreshing: false,
                busy: null,
                error: null,
              ),
              (
                name: 'conflict',
                harness: harnessWith(skill: HarnessSkillStatus.conflict),
                isRefreshing: false,
                busy: null,
                error: null,
              ),
              (
                name: 'unknown',
                harness: harnessWith(
                  skill: HarnessSkillStatus.unknown,
                  skillMessage: 'Could not read hive-skill.json.',
                ),
                isRefreshing: false,
                busy: null,
                error: null,
              ),
              (
                name: 'busy_install',
                harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
                isRefreshing: false,
                busy: SkillRowAction.install,
                error: null,
              ),
              (
                name: 'error',
                harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
                isRefreshing: false,
                busy: null,
                error: const SkillRowError(
                  failure: BackendFailure('Disk full'),
                  action: SkillRowAction.install,
                ),
              ),
              (
                name: 'mcp_missing',
                harness: harnessWith(
                  skill: HarnessSkillStatus.installed,
                  mcp: HarnessMcpStatus.notInstalled,
                ),
                isRefreshing: false,
                busy: null,
                error: null,
              ),
              (
                name: 'loading',
                harness: harnessWith(skill: HarnessSkillStatus.installed),
                isRefreshing: true,
                busy: null,
                error: null,
              ),
              (
                name: 'no_skill_row',
                harness: harnessWith(),
                isRefreshing: false,
                busy: null,
                error: null,
              ),
            ];

        for (final width in <double>[1280, 480]) {
          for (final item in cardCases) {
            await tester.pumpWidget(
              _appWrap(
                HarnessCard(
                  harness: item.harness,
                  isRefreshing: item.isRefreshing,
                  isGlobalRefreshing: false,
                  skillAction: item.busy,
                  skillError: item.error,
                  onRecheck: () {},
                  onCopyPath: (_) {},
                  onInstallMcp: () {},
                  onInstallSkill: () {},
                  onUpdateSkill: () {},
                  onRemoveSkill: () {},
                  onRetrySkill: () {},
                ),
                textScale: 2,
                maxWidth: width,
              ),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'overflow on ${item.name} at width=$width',
            );

            final cardRect = tester.getRect(find.byType(HarnessCard));
            for (final buttonFinder in <Finder>[
              find.byType(HiveButton),
              find.byType(HiveIconButton),
            ]) {
              for (final element in buttonFinder.evaluate()) {
                final rect = tester.getRect(find.byWidget(element.widget));
                expect(
                  cardRect.left <= rect.left + 0.5 &&
                      cardRect.right >= rect.right - 0.5 &&
                      cardRect.top <= rect.top + 0.5 &&
                      cardRect.bottom >= rect.bottom - 0.5,
                  isTrue,
                  reason:
                      '${element.widget.key} out of card bounds on '
                      '${item.name} at width=$width ($rect not in $cardRect)',
                );
              }
            }
          }
        }

        // Banners at 2x text.
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
              mcp: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.installed,
              ),
            ),
          ],
        );
        final partialNotice = SkillAutoInstallNotice(
          id: 'n2',
          createdAt: DateTime.utc(2026, 11, 20),
          results: const <SkillAutoInstallHarnessResult>[
            SkillAutoInstallHarnessResult(
              harnessId: HarnessId.codex,
              skill: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.failed,
                message: 'Permission denied',
              ),
              mcp: SkillAutoInstallStep(
                outcome: SkillAutoInstallOutcome.installed,
              ),
            ),
          ],
        );

        for (final notice in <SkillAutoInstallNotice>[
          installedNotice,
          partialNotice,
        ]) {
          await tester.pumpWidget(
            _appWrap(
              SkillAutoInstallBanner(
                state: SkillNoticeState(notice: notice),
                onUndo: () {},
                onRetry: () {},
                onDismiss: () {},
              ),
              textScale: 2,
              maxWidth: 1280,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        // Settings section at 2x text.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
              themePreferenceStoreProvider.overrideWithValue(_FakeThemeStore()),
              filePickerDataSourceProvider.overrideWithValue(_FakePicker()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: HiveTheme.dark(),
              home: const MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(body: SettingsPage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Long content: 140-char conflict/skillMessage, 12-segment Windows path, '
      'and 6-harness outdated banner wrap without overflow',
      (tester) async {
        final long140 = List<String>.filled(14, '0123456789').join();
        expect(long140.length, 140);

        await tester.pumpWidget(
          _appWrap(
            HarnessSkillRow(
              harness: harnessWith(
                skill: HarnessSkillStatus.unknown,
                skillMessage: long140,
              ),
              isDisabled: false,
              onInstall: () {},
              onUpdate: () {},
              onRemove: () {},
              onRecheck: () {},
              onRetry: () {},
            ),
            maxWidth: 480,
          ),
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _appWrap(
            HarnessSkillRow(
              harness: harnessWith(
                skill: HarnessSkillStatus.conflict,
                skillMessage: long140,
              ),
              isDisabled: false,
              error: SkillRowError(
                failure: BackendFailure(long140),
                action: SkillRowAction.install,
              ),
              onInstall: () {},
              onUpdate: () {},
              onRemove: () {},
              onRecheck: () {},
              onRetry: () {},
            ),
            maxWidth: 480,
          ),
        );
        expect(tester.takeException(), isNull);

        const winPath =
            r'C:\Users\Administrator\AppData\Local\Programs\AgenticHive\'
            r'profiles\work\harnesses\claude\skills\agentic-hive';
        await tester.pumpWidget(
          _appWrap(
            SkillAutoInstallBanner(
              state: SkillNoticeState(
                notice: SkillAutoInstallNotice(
                  id: 'n-long',
                  createdAt: DateTime.utc(2026, 11, 20),
                  results: const <SkillAutoInstallHarnessResult>[
                    SkillAutoInstallHarnessResult(
                      harnessId: HarnessId.claudeCode,
                      skill: SkillAutoInstallStep(
                        outcome: SkillAutoInstallOutcome.installed,
                        paths: <String>[winPath],
                      ),
                      mcp: SkillAutoInstallStep(
                        outcome: SkillAutoInstallOutcome.installed,
                      ),
                    ),
                  ],
                ),
              ),
              onUndo: () {},
              onRetry: () {},
              onDismiss: () {},
            ),
            maxWidth: 480,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Verify Text.rich composes harness label + mono path and preserves
        // exact semantics label.
        expect(find.bySemanticsLabel('Claude Code: $winPath'), findsOneWidget);

        // 6-harness outdated list.
        final sixHarnesses = <HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
          harnessWith(id: HarnessId.codex, skill: HarnessSkillStatus.outdated),
          harnessWith(
            id: HarnessId.geminiCli,
            skill: HarnessSkillStatus.outdated,
          ),
          harnessWith(
            id: HarnessId.antigravity,
            skill: HarnessSkillStatus.outdated,
          ),
          harnessWith(skill: HarnessSkillStatus.outdated)
              .copyWith(displayName: 'Harness Five'),
          harnessWith(
            id: HarnessId.codex,
            skill: HarnessSkillStatus.outdated,
          ).copyWith(displayName: 'Harness Six'),
        ];
        final harnessRepo = ScriptedHarnessRepository()
          ..getResult = Success(sixHarnesses);
        addTearDown(harnessRepo.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              harnessRepositoryProvider.overrideWithValue(harnessRepo),
              outdatedBannerStoreProvider.overrideWithValue(
                MemoryOutdatedBannerStore(),
              ),
              appVersionProvider.overrideWithValue('1.0.0'),
            ],
            child: _appWrap(const OutdatedToolsBanner(), maxWidth: 480),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Wrapping layout: at card width = space8 * 5 skill row wraps action '
      'under the tag instead of overflowing',
      (tester) async {
        final narrowWidth = HiveSpacing.standard.space8 * 5;
        await tester.pumpWidget(
          _appWrap(
            HarnessCard(
              harness: harnessWith(skill: HarnessSkillStatus.notInstalled),
              isRefreshing: false,
              isGlobalRefreshing: false,
              onRecheck: () {},
              onCopyPath: (_) {},
              onInstallMcp: () {},
              onInstallSkill: () {},
            ),
            maxWidth: narrowWidth,
            textScale: 1.5,
          ),
        );
        expect(tester.takeException(), isNull);

        final skillRow = find.byKey(
          const ValueKey<String>('harness_skill_row_claude_code'),
        );
        final badgeFinder = find.descendant(
          of: skillRow,
          matching: find.byType(HiveBadge),
        );
        final buttonFinder = find.byKey(
          const ValueKey<String>('harness_skill_install_claude_code'),
        );
        expect(
          tester.getTopLeft(buttonFinder).dy,
          greaterThan(tester.getTopLeft(badgeFinder).dy),
        );
      },
    );

    testWidgets('Semantics unchanged: live regions, labeled controls, and '
        'labeledTapTargetGuideline on styled widgets', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _appWrap(
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
    });
  });
}
