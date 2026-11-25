import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/skills/skill_notice_repository_impl.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/skill_notice_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harnesses/scripted_harness_repository.dart';
import 'scripted_skill_notice_repository.dart';

void main() {
  SkillAutoInstallNotice makeNotice({
    String id = 'n1',
    SkillAutoInstallOutcome claudeSkill = SkillAutoInstallOutcome.installed,
    SkillAutoInstallOutcome claudeMcp = SkillAutoInstallOutcome.installed,
    String? claudeSkillMessage,
    String? claudeMcpMessage,
    SkillAutoInstallOutcome? codexSkill,
    SkillAutoInstallOutcome? codexMcp,
    String? codexMcpMessage,
  }) => SkillAutoInstallNotice(
    id: id,
    createdAt: DateTime.utc(2026, 11, 20),
    results: <SkillAutoInstallHarnessResult>[
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.claudeCode,
        skill: SkillAutoInstallStep(
          outcome: claudeSkill,
          paths: claudeSkill == SkillAutoInstallOutcome.installed
              ? const <String>['/home/.claude/skills/agentic-hive']
              : const <String>[],
          message: claudeSkillMessage,
        ),
        mcp: SkillAutoInstallStep(
          outcome: claudeMcp,
          message: claudeMcpMessage,
        ),
      ),
      if (codexSkill != null && codexMcp != null)
        SkillAutoInstallHarnessResult(
          harnessId: HarnessId.codex,
          skill: SkillAutoInstallStep(
            outcome: codexSkill,
            paths: codexSkill == SkillAutoInstallOutcome.installed
                ? const <String>['/home/.agents/skills/agentic-hive']
                : const <String>[],
          ),
          mcp: SkillAutoInstallStep(
            outcome: codexMcp,
            message: codexMcpMessage,
          ),
        ),
    ],
  );

  group('SkillNoticeController', () {
    test('loads initial GET notice and updates on WS event', () async {
      final first = makeNotice();
      final second = makeNotice(id: 'n2');
      final noticeRepo = ScriptedSkillNoticeRepository()
        ..getResult = Success(first);
      final harnessRepo = ScriptedHarnessRepository();
      addTearDown(noticeRepo.dispose);
      addTearDown(harnessRepo.dispose);

      final container = ProviderContainer.test(
        overrides: [
          skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
        ],
      )..listen(skillNoticeControllerProvider, (_, _) {});

      final initial = await container.read(
        skillNoticeControllerProvider.future,
      );
      expect(initial.notice, first);
      expect(initial.isPartial, isFalse);

      noticeRepo.notices.add(second);
      await pumpEventQueue();

      expect(
        container.read(skillNoticeControllerProvider).value?.notice,
        second,
      );
    });

    test('WS event arriving before GET completes wins', () async {
      final pendingGet = Completer<Result<SkillAutoInstallNotice?>>();
      final wsNotice = makeNotice(id: 'ws-newer');
      final staleGetNotice = makeNotice(id: 'get-older');

      final noticeRepo = ScriptedSkillNoticeRepository()
        ..pendingGet = pendingGet;
      final harnessRepo = ScriptedHarnessRepository();
      addTearDown(noticeRepo.dispose);
      addTearDown(harnessRepo.dispose);

      final container = ProviderContainer.test(
        overrides: [
          skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
        ],
      )..listen(skillNoticeControllerProvider, (_, _) {});

      final future = container.read(skillNoticeControllerProvider.future);
      await pumpEventQueue();

      noticeRepo.notices.add(wsNotice);
      await pumpEventQueue();

      pendingGet.complete(Success(staleGetNotice));
      final state = await future;
      expect(state.notice, wsNotice);
    });

    test('GET failure resolves silently with no notice', () async {
      final noticeRepo = ScriptedSkillNoticeRepository()
        ..getResult = const FailureResult(NetworkFailure('offline'));
      final harnessRepo = ScriptedHarnessRepository();
      addTearDown(noticeRepo.dispose);
      addTearDown(harnessRepo.dispose);

      final container = ProviderContainer.test(
        overrides: [
          skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
        ],
      );

      final state = await container.read(skillNoticeControllerProvider.future);
      expect(state.notice, isNull);
    });

    test(
      'dismiss calls DELETE and clears locally even when DELETE fails',
      () async {
        final notice = makeNotice();
        final noticeRepo = ScriptedSkillNoticeRepository()
          ..getResult = Success(notice)
          ..dismissResult = const FailureResult(NetworkFailure('offline'));
        final harnessRepo = ScriptedHarnessRepository();
        addTearDown(noticeRepo.dispose);
        addTearDown(harnessRepo.dispose);

        final container = ProviderContainer.test(
          overrides: [
            skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
            harnessRepositoryProvider.overrideWithValue(harnessRepo),
          ],
        )..listen(skillNoticeControllerProvider, (_, _) {});

        await container.read(skillNoticeControllerProvider.future);
        await container.read(skillNoticeControllerProvider.notifier).dismiss();

        expect(noticeRepo.dismissCalls, 1);
        expect(
          container.read(skillNoticeControllerProvider).value?.notice,
          isNull,
        );
      },
    );

    test(
      'undo removes only harnesses with skill.outcome == installed',
      () async {
        final notice = makeNotice(
          codexSkill: SkillAutoInstallOutcome.alreadyInstalled,
          codexMcp: SkillAutoInstallOutcome.installed,
        );
        final noticeRepo = ScriptedSkillNoticeRepository()
          ..getResult = Success(notice);
        final harnessRepo = ScriptedHarnessRepository()
          ..removeSkillResult = Success(
            harnessWith(skill: HarnessSkillStatus.notInstalled),
          );
        addTearDown(noticeRepo.dispose);
        addTearDown(harnessRepo.dispose);

        final container = ProviderContainer.test(
          overrides: [
            skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
            harnessRepositoryProvider.overrideWithValue(harnessRepo),
          ],
        )..listen(skillNoticeControllerProvider, (_, _) {});

        await container.read(skillNoticeControllerProvider.future);
        final result = await container
            .read(skillNoticeControllerProvider.notifier)
            .undo();

        expect(result.isSuccess, isTrue);
        expect(harnessRepo.removeSkillCalls, <HarnessId>[HarnessId.claudeCode]);
        expect(noticeRepo.dismissCalls, 1);
        expect(
          container.read(skillNoticeControllerProvider).value?.notice,
          isNull,
        );
      },
    );

    test('undo failure keeps notice and returns first failure', () async {
      final notice = makeNotice();
      final noticeRepo = ScriptedSkillNoticeRepository()
        ..getResult = Success(notice);
      final harnessRepo = ScriptedHarnessRepository()
        ..removeSkillResult = const FailureResult(
          BackendFailure('Cannot delete'),
        );
      addTearDown(noticeRepo.dispose);
      addTearDown(harnessRepo.dispose);

      final container = ProviderContainer.test(
        overrides: [
          skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
        ],
      )..listen(skillNoticeControllerProvider, (_, _) {});

      await container.read(skillNoticeControllerProvider.future);
      final result = await container
          .read(skillNoticeControllerProvider.notifier)
          .undo();

      expect(result.failureOrNull?.message, 'Cannot delete');
      expect(noticeRepo.dismissCalls, 0);
      expect(
        container.read(skillNoticeControllerProvider).value?.notice,
        notice,
      );
    });

    test('retryFailed retries only failed steps, drops resolved ones, '
        'updates messages, and dismisses when all succeed', () async {
      final notice = makeNotice(
        claudeSkill: SkillAutoInstallOutcome.failed,
        claudeSkillMessage: 'Old skill error',
        codexSkill: SkillAutoInstallOutcome.installed,
        codexMcp: SkillAutoInstallOutcome.failed,
        codexMcpMessage: 'Old mcp error',
      );
      final noticeRepo = ScriptedSkillNoticeRepository()
        ..getResult = Success(notice);
      final harnessRepo = ScriptedHarnessRepository()
        ..installSkillResult = Success(
          harnessWith(skill: HarnessSkillStatus.installed),
        )
        ..installMcpResult = const FailureResult(
          BackendFailure('New mcp error'),
        );
      addTearDown(noticeRepo.dispose);
      addTearDown(harnessRepo.dispose);

      final container = ProviderContainer.test(
        overrides: [
          skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
          harnessRepositoryProvider.overrideWithValue(harnessRepo),
        ],
      )..listen(skillNoticeControllerProvider, (_, _) {});

      final initial = await container.read(
        skillNoticeControllerProvider.future,
      );
      expect(initial.isPartial, isTrue);
      expect(initial.failures, hasLength(2));

      await container
          .read(skillNoticeControllerProvider.notifier)
          .retryFailed();

      expect(
        harnessRepo.installSkillCalls,
        <({HarnessId id, bool overwriteModified})>[
          (id: HarnessId.claudeCode, overwriteModified: false),
        ],
      );
      expect(harnessRepo.installMcpCalls, <HarnessId>[HarnessId.codex]);

      final mid = container.read(skillNoticeControllerProvider).value!;
      expect(mid.isPartial, isTrue);
      expect(mid.failures, <SkillNoticeFailure>[
        (
          harnessId: HarnessId.codex,
          step: SkillNoticeStep.mcp,
          message: 'New mcp error',
        ),
      ]);
      expect(noticeRepo.dismissCalls, 0);

      harnessRepo.installMcpResult = Success(
        harnessWith(id: HarnessId.codex, skill: HarnessSkillStatus.installed),
      );
      await container
          .read(skillNoticeControllerProvider.notifier)
          .retryFailed();

      expect(noticeRepo.dismissCalls, 1);
      expect(
        container.read(skillNoticeControllerProvider).value?.notice,
        isNull,
      );
    });
  });
}
