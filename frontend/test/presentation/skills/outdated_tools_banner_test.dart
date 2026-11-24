import 'package:agentic_hive_frontend/core/backend/app_version_provider.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/outdated_tools_banner.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../harnesses/scripted_harness_repository.dart';
import 'memory_outdated_banner_store.dart';

void main() {
  group('OutdatedToolsBanner', () {
    testWidgets('dismiss acknowledges version and hides banner', (
      tester,
    ) async {
      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
          harnessWith(
            id: HarnessId.codex,
            skill: HarnessSkillStatus.installed,
            mcp: HarnessMcpStatus.outdated,
          ),
        ]);
      addTearDown(harnessRepo.dispose);
      final store = MemoryOutdatedBannerStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            harnessRepositoryProvider.overrideWithValue(harnessRepo),
            outdatedBannerStoreProvider.overrideWithValue(store),
            appVersionProvider.overrideWithValue('1.5.0'),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: HiveTheme.dark(),
            home: const Scaffold(body: OutdatedToolsBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final banner = tester.widget<HiveBanner>(
        find.byKey(const ValueKey<String>('outdated_tools_banner')),
      );
      expect(banner.tone, HiveFeedbackTone.warning);
      expect(banner.liveRegion, isTrue);
      expect(
        banner.title,
        'Agentic Hive tools need an update for Claude Code, Codex.',
      );

      await tester.tap(find.bySemanticsLabel('Dismiss update notice'));
      await tester.pumpAndSettle();

      expect(store.savedVersions, <String>['1.5.0']);
    });

    testWidgets('Open Harnesses saves version and navigates to /harnesses', (
      tester,
    ) async {
      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
        ]);
      addTearDown(harnessRepo.dispose);
      final store = MemoryOutdatedBannerStore();

      final router = GoRouter(
        initialLocation: OverviewRoute.path,
        routes: <RouteBase>[
          GoRoute(
            path: OverviewRoute.path,
            builder: (_, _) => const Scaffold(body: OutdatedToolsBanner()),
          ),
          GoRoute(
            path: HarnessesRoute.path,
            builder: (_, _) => const Scaffold(body: Text('Harnesses Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            harnessRepositoryProvider.overrideWithValue(harnessRepo),
            outdatedBannerStoreProvider.overrideWithValue(store),
            appVersionProvider.overrideWithValue('1.5.0'),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: HiveTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('outdated_tools_open')),
      );
      await tester.pumpAndSettle();

      expect(store.savedVersions, <String>['1.5.0']);
      expect(find.text('Harnesses Target'), findsOneWidget);
    });
  });
}
