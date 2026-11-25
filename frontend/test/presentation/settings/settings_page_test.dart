import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_controller.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:agentic_hive_frontend/data/settings/file_picker_data_source.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/settings/pages/settings_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeSettingsRepository implements SettingsRepository {
  Result<AppSettings> getResult = const Success(
    AppSettings(
      agentsDir: '/custom/agents',
      effectiveAgentsDir: '/custom/agents',
      defaultAgentsDir: '/default/agents',
      harnessOverrides: <HarnessId, String>{
        HarnessId.claudeCode: '/usr/local/bin/claude',
      },
    ),
  );
  Result<AppSettings> updateResult = const Success(
    AppSettings(
      agentsDir: '/custom/agents',
      effectiveAgentsDir: '/custom/agents',
      defaultAgentsDir: '/default/agents',
    ),
  );
  UpdateSettingsRequest? lastRequest;
  final StreamController<AppSettings> updates =
      StreamController<AppSettings>.broadcast();

  @override
  Future<Result<AppSettings>> getSettings() async => getResult;

  @override
  Future<Result<AppSettings>> updateSettings(
    UpdateSettingsRequest request,
  ) async {
    lastRequest = request;
    return updateResult;
  }

  @override
  Stream<AppSettings> watchSettingsUpdates() => updates.stream;

  Future<void> dispose() => updates.close();
}

final class _FakeThemePreferenceStore implements ThemePreferenceStore {
  AppThemePreference current = AppThemePreference.dark;
  final List<AppThemePreference> saved = <AppThemePreference>[];

  @override
  Future<AppThemePreference> load() async => current;

  @override
  Future<void> save(AppThemePreference preference) async {
    current = preference;
    saved.add(preference);
  }
}

final class _FakeFilePickerDataSource implements FilePickerDataSource {
  String? nextDirectory;
  String? nextFile;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async =>
      nextDirectory;

  @override
  Future<String?> pickFile({String? initialDirectory}) async => nextFile;
}

Widget _buildTestApp() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: HiveTheme.dark(),
  home: const Scaffold(body: SettingsPage()),
);

void main() {
  const desktopSize = Size(1280, 900);

  void configureDesktopWindow(WidgetTester tester) {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('SettingsPage', () {
    testWidgets('switches theme immediately and persists locally', (
      tester,
    ) async {
      configureDesktopWindow(tester);
      final repo = _FakeSettingsRepository();
      addTearDown(repo.dispose);
      final themeStore = _FakeThemePreferenceStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
            themePreferenceStoreProvider.overrideWithValue(themeStore),
          ],
          child: _buildTestApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
      );
      expect(
        container.read(themePreferenceControllerProvider),
        AppThemePreference.dark,
      );

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(
        container.read(themePreferenceControllerProvider),
        AppThemePreference.light,
      );
      expect(themeStore.saved, <AppThemePreference>[AppThemePreference.light]);
    });

    testWidgets(
      'supports Browse, Reset, Clear, Discard, and Save with HiveToast',
      (tester) async {
        configureDesktopWindow(tester);
        final repo = _FakeSettingsRepository();
        addTearDown(repo.dispose);
        final picker = _FakeFilePickerDataSource()
          ..nextDirectory = '/picked/agents'
          ..nextFile = '/picked/codex';
        final themeStore = _FakeThemePreferenceStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(repo),
              filePickerDataSourceProvider.overrideWithValue(picker),
              themePreferenceStoreProvider.overrideWithValue(themeStore),
            ],
            child: _buildTestApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Browse Agents folder -> enables Save & Discard.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('settings_agents_dir_browse_button'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('/picked/agents'), findsOneWidget);

        // Discard reverts back to saved '/custom/agents'.
        await tester.tap(
          find.byKey(const ValueKey<String>('settings_discard_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('/picked/agents'), findsNothing);
        expect(find.text('/custom/agents'), findsOneWidget);

        // Reset Agents folder, Browse Codex executable.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('settings_agents_dir_reset_button'),
          ),
        );
        final codexBrowse = find.byKey(
          const ValueKey<String>('settings_harness_codex_browse_button'),
        );
        await tester.ensureVisible(codexBrowse);
        await tester.tap(codexBrowse);
        await tester.pumpAndSettle();

        repo.updateResult = const Success(
          AppSettings(
            effectiveAgentsDir: '/default/agents',
            defaultAgentsDir: '/default/agents',
            harnessOverrides: <HarnessId, String>{
              HarnessId.claudeCode: '/usr/local/bin/claude',
              HarnessId.codex: '/picked/codex',
            },
          ),
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('settings_save_button')),
        );
        await tester.pumpAndSettle();

        expect(repo.lastRequest?.agentsDir, isNull);
        expect(
          repo.lastRequest?.harnessOverrides[HarnessId.codex],
          '/picked/codex',
        );
        expect(find.byType(HiveToast), findsOneWidget);
        expect(find.text('Settings saved'), findsOneWidget);
      },
    );

    testWidgets(
      'displays inline per-field validation errors without losing draft',
      (tester) async {
        configureDesktopWindow(tester);
        final repo = _FakeSettingsRepository();
        addTearDown(repo.dispose);
        final picker = _FakeFilePickerDataSource()
          ..nextDirectory = '/bad/agents';
        final themeStore = _FakeThemePreferenceStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(repo),
              filePickerDataSourceProvider.overrideWithValue(picker),
              themePreferenceStoreProvider.overrideWithValue(themeStore),
            ],
            child: _buildTestApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('settings_agents_dir_browse_button'),
          ),
        );
        await tester.pumpAndSettle();

        repo.updateResult = const FailureResult<AppSettings>(
          ValidationFailure(
            'Settings validation failed.',
            details: <String, String>{
              'agentsDir': 'Agents folder does not exist.',
            },
          ),
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('settings_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Agents folder does not exist.'), findsOneWidget);
        expect(find.text('/bad/agents'), findsOneWidget);
        expect(find.byType(HiveToast), findsNothing);
      },
    );

    testWidgets(
      'autoInstallSkills switch reflects saved value, enables Save on '
      'toggle, and renders help text',
      (tester) async {
        configureDesktopWindow(tester);
        final repo = _FakeSettingsRepository();
        addTearDown(repo.dispose);
        final themeStore = _FakeThemePreferenceStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(repo),
              themePreferenceStoreProvider.overrideWithValue(themeStore),
            ],
            child: _buildTestApp(),
          ),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byKey(
          const ValueKey<String>('settings_auto_install_skills_switch'),
        );
        await tester.ensureVisible(switchFinder);
        final hiveSwitch = tester.widget<HiveSwitch>(switchFinder);
        expect(hiveSwitch.value, isTrue);
        expect(
          hiveSwitch.label,
          'Install the skill automatically for new harnesses',
        );
        expect(
          find.text(
            'The first time Agentic Hive finds a harness, it installs the '
            'agentic-hive skill and the Hive MCP server for it. It never '
            'updates them by itself.',
          ),
          findsOneWidget,
        );

        expect(
          tester
              .widget<HiveButton>(
                find.byKey(const ValueKey<String>('settings_save_button')),
              )
              .onPressed,
          isNull,
        );

        await tester.tap(
          find.descendant(
            of: switchFinder,
            matching: find.byType(HiveInteraction),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.widget<HiveSwitch>(switchFinder).value, isFalse);
        expect(
          tester
              .widget<HiveButton>(
                find.byKey(const ValueKey<String>('settings_save_button')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );
  });
}
