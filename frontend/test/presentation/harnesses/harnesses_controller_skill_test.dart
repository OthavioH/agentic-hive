import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_harness_repository.dart';

void main() {
  group('HarnessesController skill actions', () {
    test('installSkill marks busy, upserts harness, and unmarks', () async {
      final pending = Completer<Result<HarnessInfo>>();
      final claudeNotInstalled = harnessWith(
        skill: HarnessSkillStatus.notInstalled,
      );
      final repo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[claudeNotInstalled])
        ..pendingInstallSkill = pending;
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = container.listen(harnessesControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(harnessesControllerProvider.future);

      final future = container
          .read(harnessesControllerProvider.notifier)
          .installSkill(HarnessId.claudeCode, action: SkillRowAction.install);

      expect(
        container.read(harnessesControllerProvider).value?.skillActions,
        <HarnessId, SkillRowAction>{
          HarnessId.claudeCode: SkillRowAction.install,
        },
      );

      final installed = claudeNotInstalled.copyWith(
        skillStatus: HarnessSkillStatus.installed,
      );
      pending.complete(Success(installed));

      final result = await future;
      expect(result.isSuccess, isTrue);
      final after = container.read(harnessesControllerProvider).value!;
      expect(after.skillActions, isEmpty);
      expect(after.skillErrors, isEmpty);
      expect(after.harnesses, <HarnessInfo>[installed]);
    });

    test('removeSkill marks busy, upserts harness, and unmarks', () async {
      final pending = Completer<Result<HarnessInfo>>();
      final claudeInstalled = harnessWith(skill: HarnessSkillStatus.installed);
      final repo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[claudeInstalled])
        ..pendingRemoveSkill = pending;
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = container.listen(harnessesControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(harnessesControllerProvider.future);

      final future = container
          .read(harnessesControllerProvider.notifier)
          .removeSkill(HarnessId.claudeCode);

      expect(
        container.read(harnessesControllerProvider).value?.skillActions,
        <HarnessId, SkillRowAction>{
          HarnessId.claudeCode: SkillRowAction.remove,
        },
      );

      final removed = claudeInstalled.copyWith(
        skillStatus: HarnessSkillStatus.notInstalled,
      );
      pending.complete(Success(removed));

      final result = await future;
      expect(result.isSuccess, isTrue);
      final after = container.read(harnessesControllerProvider).value!;
      expect(after.skillActions, isEmpty);
      expect(after.harnesses, <HarnessInfo>[removed]);
    });

    test('failure stores SkillRowError with action and overwriteModified and '
        'unmarks', () async {
      final claudeModified = harnessWith(skill: HarnessSkillStatus.modified);
      final repo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[claudeModified])
        ..installSkillResult = const FailureResult<HarnessInfo>(
          BackendFailure('Permission denied', statusCode: 500),
        );
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = container.listen(harnessesControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(harnessesControllerProvider.future);

      final result = await container
          .read(harnessesControllerProvider.notifier)
          .installSkill(
            HarnessId.claudeCode,
            action: SkillRowAction.update,
            overwriteModified: true,
          );

      expect(result.failureOrNull, isA<BackendFailure>());
      final after = container.read(harnessesControllerProvider).value!;
      expect(after.skillActions, isEmpty);
      expect(
        after.skillErrors[HarnessId.claudeCode],
        isA<SkillRowError>()
            .having((e) => e.action, 'action', SkillRowAction.update)
            .having((e) => e.overwriteModified, 'overwriteModified', isTrue)
            .having(
              (e) => e.failure.message,
              'failure.message',
              'Permission denied',
            ),
      );
    });

    test('second call while busy is a no-op', () async {
      final pending = Completer<Result<HarnessInfo>>();
      final claude = harnessWith(skill: HarnessSkillStatus.notInstalled);
      final repo = ScriptedHarnessRepository()
        ..getResult = Success(<HarnessInfo>[claude])
        ..pendingInstallSkill = pending;
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = container.listen(harnessesControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(harnessesControllerProvider.future);

      final notifier = container.read(harnessesControllerProvider.notifier);
      final first = notifier.installSkill(
        HarnessId.claudeCode,
        action: SkillRowAction.install,
      );
      final second = await notifier.installSkill(
        HarnessId.claudeCode,
        action: SkillRowAction.install,
      );

      expect(second.isSuccess, isTrue);
      expect(repo.installSkillCalls, hasLength(1));

      pending.complete(
        Success(claude.copyWith(skillStatus: HarnessSkillStatus.installed)),
      );
      await first;
    });

    test(
      'clearSkillError, new action, and refreshHarness clear stored error',
      () async {
        final claude = harnessWith(skill: HarnessSkillStatus.notInstalled);
        final repo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[claude])
          ..installSkillResult = const FailureResult<HarnessInfo>(
            BackendFailure('First failure'),
          );
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
        );
        final sub = container.listen(harnessesControllerProvider, (_, _) {});
        addTearDown(sub.close);

        await container.read(harnessesControllerProvider.future);
        final notifier = container.read(harnessesControllerProvider.notifier);

        await notifier.installSkill(
          HarnessId.claudeCode,
          action: SkillRowAction.install,
        );
        expect(
          container
              .read(harnessesControllerProvider)
              .value
              ?.skillErrors
              .containsKey(HarnessId.claudeCode),
          isTrue,
        );

        notifier.clearSkillError(HarnessId.claudeCode);
        expect(
          container
              .read(harnessesControllerProvider)
              .value
              ?.skillErrors
              .containsKey(HarnessId.claudeCode),
          isFalse,
        );

        // New action clears previous error while running.
        await notifier.installSkill(
          HarnessId.claudeCode,
          action: SkillRowAction.install,
        );
        expect(
          container
              .read(harnessesControllerProvider)
              .value
              ?.skillErrors
              .containsKey(HarnessId.claudeCode),
          isTrue,
        );

        final pending = Completer<Result<HarnessInfo>>();
        repo.pendingInstallSkill = pending;
        final retryFuture = notifier.installSkill(
          HarnessId.claudeCode,
          action: SkillRowAction.install,
        );
        expect(
          container
              .read(harnessesControllerProvider)
              .value
              ?.skillErrors
              .containsKey(HarnessId.claudeCode),
          isFalse,
        );
        pending.complete(
          const FailureResult<HarnessInfo>(BackendFailure('Retry failed')),
        );
        await retryFuture;

        // refreshHarness success clears the error.
        repo.refreshOneResult = Success(claude);
        await notifier.refreshHarness(HarnessId.claudeCode);
        expect(
          container
              .read(harnessesControllerProvider)
              .value
              ?.skillErrors
              .containsKey(HarnessId.claudeCode),
          isFalse,
        );
      },
    );

    test(
      'returns failure without throwing when disposed while awaiting',
      () async {
        final pending = Completer<Result<HarnessInfo>>();
        final claude = harnessWith(skill: HarnessSkillStatus.notInstalled);
        final repo = ScriptedHarnessRepository()
          ..getResult = Success(<HarnessInfo>[claude])
          ..pendingInstallSkill = pending;
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
        );

        await container.read(harnessesControllerProvider.future);
        final future = container
            .read(harnessesControllerProvider.notifier)
            .installSkill(HarnessId.claudeCode, action: SkillRowAction.install);

        container.dispose();
        pending.complete(
          Success(claude.copyWith(skillStatus: HarnessSkillStatus.installed)),
        );

        final result = await future;
        expect(result.failureOrNull, isA<UnexpectedFailure>());
      },
    );
  });
}
