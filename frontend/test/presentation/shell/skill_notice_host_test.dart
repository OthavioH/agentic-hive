import 'package:agentic_hive_frontend/core/backend/app_version_provider.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:agentic_hive_frontend/data/skills/skill_notice_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_tree_changes_providers.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/shell/widgets/app_shell.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/outdated_tools_banner.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/skill_auto_install_banner.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/skill_notice_host.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../harnesses/scripted_harness_repository.dart';
import '../skills/memory_outdated_banner_store.dart';
import '../skills/scripted_skill_notice_repository.dart';
import '../workspace/fake_workspace_repository.dart';

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String? workspaceId) async {}
}

final class _NoChangesSource implements WorkspaceTreeChangesSource {
  @override
  Stream<WorkspaceTreeChange> get changes =>
      const Stream<WorkspaceTreeChange>.empty();
}

final class _FakeRunsRepo implements RunRepository {
  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async => const Success<RunsListResponse>(
    RunsListResponse(items: <RunSummary>[], total: 0),
  );

  @override
  Future<Result<Run>> cancelRun(String id) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteRun(String id) => throw UnimplementedError();

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> getRun(String id) => throw UnimplementedError();

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> resumeRun(String id) => throw UnimplementedError();

  @override
  Future<Result<Run>> startRun(StartRunRequest request) =>
      throw UnimplementedError();
}

final class _FakePauseRepo implements PauseRepository {
  @override
  Future<Result<List<Pause>>> listPendingPauses() async =>
      const Success<List<Pause>>(<Pause>[]);

  @override
  Future<Result<Pause>> answerPause(String id, AnswerPauseRequest request) =>
      throw UnimplementedError();

  @override
  Stream<PauseEvent> watchPauseEvents() => const Stream<PauseEvent>.empty();

  @override
  Stream<int> watchPendingPausesCount() => const Stream<int>.empty();
}

Widget _mountShell({required String location}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: HiveTheme.dark(),
  home: AppShell(location: location, child: const SizedBox.expand()),
);

void main() {
  const desktopSize = Size(1280, 900);

  final sampleNotice = SkillAutoInstallNotice(
    id: 'n1',
    createdAt: DateTime.utc(2026, 11, 20),
    results: const <SkillAutoInstallHarnessResult>[
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.claudeCode,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.installed,
          paths: <String>['/home/.claude/skills/agentic-hive'],
        ),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
      ),
    ],
  );

  group('SkillNoticeHost', () {
    testWidgets('stacks first-run banner above outdated banner on /overview', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
        ]);
      final noticeRepo = ScriptedSkillNoticeRepository()
        ..getResult = Success(sampleNotice);
      addTearDown(harnessRepo.dispose);
      addTearDown(noticeRepo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(
              FakeWorkspaceRepository(),
            ),
            workspaceSelectionStoreProvider.overrideWithValue(
              _FakeSelectionStore(),
            ),
            runRepositoryProvider.overrideWithValue(_FakeRunsRepo()),
            pauseRepositoryProvider.overrideWithValue(_FakePauseRepo()),
            workspaceTreeChangesSourceProvider.overrideWithValue(
              _NoChangesSource(),
            ),
            harnessRepositoryProvider.overrideWithValue(harnessRepo),
            skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
            outdatedBannerStoreProvider.overrideWithValue(
              MemoryOutdatedBannerStore(),
            ),
            appVersionProvider.overrideWithValue('1.0.0'),
          ],
          child: _mountShell(location: '/overview'),
        ),
      );
      await tester.pumpAndSettle();

      final firstRunFinder = find.byType(SkillAutoInstallBanner);
      final outdatedFinder = find.byType(OutdatedToolsBanner);
      expect(firstRunFinder, findsOneWidget);
      expect(outdatedFinder, findsOneWidget);

      expect(
        tester.getTopLeft(firstRunFinder).dy,
        lessThan(tester.getTopLeft(outdatedFinder).dy),
      );
    });

    testWidgets('hides outdated banner on /harnesses', (tester) async {
      await tester.binding.setSurfaceSize(desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
        ]);
      final noticeRepo = ScriptedSkillNoticeRepository()
        ..getResult = Success(sampleNotice);
      addTearDown(harnessRepo.dispose);
      addTearDown(noticeRepo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(
              FakeWorkspaceRepository(),
            ),
            workspaceSelectionStoreProvider.overrideWithValue(
              _FakeSelectionStore(),
            ),
            runRepositoryProvider.overrideWithValue(_FakeRunsRepo()),
            pauseRepositoryProvider.overrideWithValue(_FakePauseRepo()),
            workspaceTreeChangesSourceProvider.overrideWithValue(
              _NoChangesSource(),
            ),
            harnessRepositoryProvider.overrideWithValue(harnessRepo),
            skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
            outdatedBannerStoreProvider.overrideWithValue(
              MemoryOutdatedBannerStore(),
            ),
            appVersionProvider.overrideWithValue('1.0.0'),
          ],
          child: _mountShell(location: '/harnesses'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkillAutoInstallBanner), findsOneWidget);
      expect(find.byType(OutdatedToolsBanner), findsNothing);
    });

    testWidgets('renders zero height when neither banner shows', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final harnessRepo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.installed),
        ]);
      final noticeRepo = ScriptedSkillNoticeRepository();
      addTearDown(harnessRepo.dispose);
      addTearDown(noticeRepo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(
              FakeWorkspaceRepository(),
            ),
            workspaceSelectionStoreProvider.overrideWithValue(
              _FakeSelectionStore(),
            ),
            runRepositoryProvider.overrideWithValue(_FakeRunsRepo()),
            pauseRepositoryProvider.overrideWithValue(_FakePauseRepo()),
            workspaceTreeChangesSourceProvider.overrideWithValue(
              _NoChangesSource(),
            ),
            harnessRepositoryProvider.overrideWithValue(harnessRepo),
            skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
            outdatedBannerStoreProvider.overrideWithValue(
              MemoryOutdatedBannerStore(),
            ),
            appVersionProvider.overrideWithValue('1.0.0'),
          ],
          child: _mountShell(location: '/overview'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkillAutoInstallBanner), findsNothing);
      expect(find.byType(OutdatedToolsBanner), findsNothing);
      expect(tester.getSize(find.byType(SkillNoticeHost)).height, 0);
    });
  });
}
