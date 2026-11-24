import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/app_version_provider.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/outdated_tools_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harnesses/scripted_harness_repository.dart';
import 'memory_outdated_banner_store.dart';

void main() {
  group('OutdatedToolsController', () {
    test('visible only for outdated skill or MCP', () async {
      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
          harnessWith(
            id: HarnessId.codex,
            skill: HarnessSkillStatus.installed,
            mcp: HarnessMcpStatus.outdated,
          ),
          // Current skill & MCP must not trigger it.
          harnessWith(
            id: HarnessId.geminiCli,
            status: HarnessStatus.notInstalled,
          ),
          // Modified/conflict/unknown must not trigger it.
          harnessWith(
            id: HarnessId.antigravity,
            skill: HarnessSkillStatus.modified,
          ),
        ]);
      addTearDown(harnessRepo.dispose);
      final store = MemoryOutdatedBannerStore();

      final container = ProviderContainer.test(
        overrides: [
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
          outdatedBannerStoreProvider.overrideWithValue(store),
          appVersionProvider.overrideWithValue('1.0.0'),
        ],
      );

      await container.read(harnessesControllerProvider.future);
      await container.read(outdatedBannerAcknowledgementProvider.future);

      final outdated = container.read(outdatedHarnessesProvider);
      expect(outdated, <OutdatedHarness>[
        const OutdatedHarness(
          id: HarnessId.claudeCode,
          displayName: 'Claude Code',
          skillOutdated: true,
          mcpOutdated: false,
        ),
        const OutdatedHarness(
          id: HarnessId.codex,
          displayName: 'Codex',
          skillOutdated: false,
          mcpOutdated: true,
        ),
      ]);
      expect(container.read(showOutdatedBannerProvider), isTrue);
    });

    test(
      'hidden for modified, conflict, unknown, and current skillStatus == null',
      () async {
        final harnessRepo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.modified),
            harnessWith(
              id: HarnessId.codex,
              skill: HarnessSkillStatus.conflict,
            ),
            harnessWith(
              id: HarnessId.geminiCli,
              skill: HarnessSkillStatus.unknown,
            ),
            harnessWith(id: HarnessId.antigravity),
          ]);
        addTearDown(harnessRepo.dispose);
        final store = MemoryOutdatedBannerStore();

        final container = ProviderContainer.test(
          overrides: [
            harnessRepositoryProvider.overrideWithValue(harnessRepo),
            outdatedBannerStoreProvider.overrideWithValue(store),
            appVersionProvider.overrideWithValue('1.0.0'),
          ],
        );

        await container.read(harnessesControllerProvider.future);
        await container.read(outdatedBannerAcknowledgementProvider.future);

        expect(container.read(outdatedHarnessesProvider), isEmpty);
        expect(container.read(showOutdatedBannerProvider), isFalse);
      },
    );

    test('flags outdated MCP even when skillStatus is null', () async {
      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(
            id: HarnessId.antigravity,
            mcp: HarnessMcpStatus.outdated,
          ),
        ]);
      addTearDown(harnessRepo.dispose);
      final store = MemoryOutdatedBannerStore();

      final container = ProviderContainer.test(
        overrides: [
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
          outdatedBannerStoreProvider.overrideWithValue(store),
          appVersionProvider.overrideWithValue('1.0.0'),
        ],
      );

      await container.read(harnessesControllerProvider.future);
      await container.read(outdatedBannerAcknowledgementProvider.future);

      expect(container.read(outdatedHarnessesProvider), <OutdatedHarness>[
        const OutdatedHarness(
          id: HarnessId.antigravity,
          displayName: 'Antigravity',
          skillOutdated: false,
          mcpOutdated: true,
        ),
      ]);
      expect(container.read(showOutdatedBannerProvider), isTrue);
    });

    test('hidden while acknowledgement is loading, when appVersion is null, '
        'or when stored version equals appVersion', () async {
      final pendingLoad = Completer<String?>();
      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
        ]);
      addTearDown(harnessRepo.dispose);
      final store = MemoryOutdatedBannerStore()..pendingLoad = pendingLoad;

      final loadingContainer = ProviderContainer.test(
        overrides: [
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
          outdatedBannerStoreProvider.overrideWithValue(store),
          appVersionProvider.overrideWithValue('1.0.0'),
        ],
      );
      await loadingContainer.read(harnessesControllerProvider.future);
      expect(loadingContainer.read(showOutdatedBannerProvider), isFalse);
      pendingLoad.complete('1.0.0');
      await loadingContainer.read(outdatedBannerAcknowledgementProvider.future);
      expect(loadingContainer.read(showOutdatedBannerProvider), isFalse);

      // New app version shows it again.
      final newVersionContainer = ProviderContainer.test(
        overrides: [
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
          outdatedBannerStoreProvider.overrideWithValue(
            MemoryOutdatedBannerStore(acknowledgedVersion: '1.0.0'),
          ),
          appVersionProvider.overrideWithValue('1.1.0'),
        ],
      );
      await newVersionContainer.read(harnessesControllerProvider.future);
      await newVersionContainer.read(
        outdatedBannerAcknowledgementProvider.future,
      );
      expect(newVersionContainer.read(showOutdatedBannerProvider), isTrue);

      // appVersion == null hides it.
      final nullVersionContainer = ProviderContainer.test(
        overrides: [
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
          outdatedBannerStoreProvider.overrideWithValue(
            MemoryOutdatedBannerStore(),
          ),
          appVersionProvider.overrideWithValue(null),
        ],
      );
      await nullVersionContainer.read(harnessesControllerProvider.future);
      await nullVersionContainer.read(
        outdatedBannerAcknowledgementProvider.future,
      );
      expect(nullVersionContainer.read(showOutdatedBannerProvider), isFalse);
    });

    test('acknowledge updates state in memory even when save fails', () async {
      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
        ]);
      addTearDown(harnessRepo.dispose);
      final store = MemoryOutdatedBannerStore(throwOnSave: true);

      final container = ProviderContainer.test(
        overrides: [
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
          outdatedBannerStoreProvider.overrideWithValue(store),
          appVersionProvider.overrideWithValue('2.0.0'),
        ],
      );
      await container.read(harnessesControllerProvider.future);
      await container.read(outdatedBannerAcknowledgementProvider.future);
      expect(container.read(showOutdatedBannerProvider), isTrue);

      await container
          .read(outdatedBannerAcknowledgementProvider.notifier)
          .acknowledge();
      expect(container.read(showOutdatedBannerProvider), isFalse);
    });
  });
}
