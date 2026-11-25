import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/skill_notice_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'skill_notice_state.dart';

part 'skill_notice_controller.g.dart';

/// Manages the global first-run automatic skill install notice banner.
@riverpod
class SkillNoticeController extends _$SkillNoticeController {
  @override
  Future<SkillNoticeState> build() async {
    var eventSeen = false;
    SkillAutoInstallNotice? latestEvent;
    final watchNotices = ref.watch(watchSkillNoticesUseCaseProvider);
    final subscription = watchNotices().listen((event) {
      eventSeen = true;
      latestEvent = event;
      if (!ref.mounted) return;
      state = AsyncData(SkillNoticeState(notice: event));
    });
    ref.onDispose(() => unawaited(subscription.cancel()));

    final getPending = ref.watch(getPendingSkillNoticeUseCaseProvider);
    final result = await getPending();
    if (!ref.mounted) {
      return const SkillNoticeState();
    }
    if (eventSeen) {
      return SkillNoticeState(notice: latestEvent);
    }
    return switch (result) {
      Success<SkillAutoInstallNotice?>(:final value) => SkillNoticeState(
        notice: value,
      ),
      FailureResult<SkillAutoInstallNotice?>() => const SkillNoticeState(),
    };
  }

  /// Dismisses the current notice on the backend and clears it locally.
  Future<void> dismiss() async {
    await ref.read(dismissSkillNoticeUseCaseProvider)();
    if (!ref.mounted) return;
    final current = state.asData?.value ?? const SkillNoticeState();
    state = AsyncData(
      current.copyWith(
        notice: null,
        isWorking: false,
        resolved: const <SkillNoticeStepKey>{},
        retryMessages: const <SkillNoticeStepKey, String>{},
      ),
    );
  }

  /// Removes every skill installed during this notice, keeping MCP intact, and
  /// dismisses the notice when all removals succeed.
  Future<Result<void>> undo() async {
    final current = state.asData?.value;
    if (current == null || current.isWorking) {
      return const Success<void>(null);
    }

    final targets = current.installedSkillHarnesses;
    state = AsyncData(current.copyWith(isWorking: true));

    final removeSkill = ref.read(removeHarnessSkillUseCaseProvider);
    Failure? firstFailure;
    final nextMessages = Map<SkillNoticeStepKey, String>.of(
      current.retryMessages,
    );

    for (final id in targets) {
      final result = await removeSkill(id);
      if (!ref.mounted) {
        return const FailureResult<void>(
          UnexpectedFailure('Skill notice controller was disposed.'),
        );
      }
      if (result case FailureResult<HarnessInfo>(:final failure)) {
        firstFailure ??= failure;
        nextMessages[(harnessId: id, step: SkillNoticeStep.skill)] =
            failure.message;
      }
    }

    final latest = state.asData?.value ?? current;
    if (firstFailure == null) {
      state = AsyncData(latest.copyWith(isWorking: false));
      await dismiss();
      return const Success<void>(null);
    }

    state = AsyncData(
      latest.copyWith(isWorking: false, retryMessages: nextMessages),
    );
    return FailureResult<void>(firstFailure);
  }

  /// Retries each unresolved failed step in the current notice, dismissing the
  /// notice once every failure resolves.
  Future<void> retryFailed() async {
    final current = state.asData?.value;
    if (current == null || current.isWorking) return;

    final pending = current.failures;
    state = AsyncData(current.copyWith(isWorking: true));

    final installSkill = ref.read(installHarnessSkillUseCaseProvider);
    final installMcp = ref.read(installHarnessMcpUseCaseProvider);
    final nextResolved = Set<SkillNoticeStepKey>.of(current.resolved);
    final nextMessages = Map<SkillNoticeStepKey, String>.of(
      current.retryMessages,
    );

    for (final item in pending) {
      final key = (harnessId: item.harnessId, step: item.step);
      final result = switch (item.step) {
        SkillNoticeStep.skill => await installSkill(item.harnessId),
        SkillNoticeStep.mcp => await installMcp(item.harnessId),
      };
      if (!ref.mounted) return;
      switch (result) {
        case Success<HarnessInfo>():
          nextResolved.add(key);
        case FailureResult<HarnessInfo>(:final failure):
          nextMessages[key] = failure.message;
      }
    }

    final latest = state.asData?.value ?? current;
    final updated = latest.copyWith(
      isWorking: false,
      resolved: nextResolved,
      retryMessages: nextMessages,
    );
    state = AsyncData(updated);
    if (updated.failures.isEmpty) {
      await dismiss();
    }
  }
}
