import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_notice_state.freezed.dart';

/// Which automatic-install step a [SkillNoticeStepKey] identifies.
enum SkillNoticeStep {
  /// The Agentic Hive skill copy step.
  skill,

  /// The Hive MCP server step.
  mcp,
}

/// Identifies a single step inside a [SkillAutoInstallNotice].
typedef SkillNoticeStepKey = ({HarnessId harnessId, SkillNoticeStep step});

/// A single unresolved failed step displayed by the partial-failure notice.
typedef SkillNoticeFailure = ({
  HarnessId harnessId,
  SkillNoticeStep step,
  String? message,
});

/// View state for the skill auto-install notice controller.
@freezed
sealed class SkillNoticeState with _$SkillNoticeState {
  /// Creates a [SkillNoticeState].
  const factory({
    SkillAutoInstallNotice? notice,
    @Default(false) bool isWorking,
    @Default(<SkillNoticeStepKey>{}) Set<SkillNoticeStepKey> resolved,
    @Default(<SkillNoticeStepKey, String>{})
    Map<SkillNoticeStepKey, String> retryMessages,
  }) = _SkillNoticeState;

  const new _();

  /// Unresolved failed steps remaining on [notice], preserving harness order
  /// (skill before MCP).
  List<SkillNoticeFailure> get failures {
    final results = notice?.results;
    if (results == null) return const <SkillNoticeFailure>[];
    final items = <SkillNoticeFailure>[];
    for (final result in results) {
      if (result.skill.outcome == SkillAutoInstallOutcome.failed) {
        final key = (harnessId: result.harnessId, step: SkillNoticeStep.skill);
        if (!resolved.contains(key)) {
          items.add((
            harnessId: result.harnessId,
            step: SkillNoticeStep.skill,
            message: retryMessages[key] ?? result.skill.message,
          ));
        }
      }
      if (result.mcp.outcome == SkillAutoInstallOutcome.failed) {
        final key = (harnessId: result.harnessId, step: SkillNoticeStep.mcp);
        if (!resolved.contains(key)) {
          items.add((
            harnessId: result.harnessId,
            step: SkillNoticeStep.mcp,
            message: retryMessages[key] ?? result.mcp.message,
          ));
        }
      }
    }
    return items;
  }

  /// Whether at least one failed step remains unresolved.
  bool get isPartial => failures.isNotEmpty;

  /// Harnesses whose skill step installed a copy during this notice.
  List<HarnessId> get installedSkillHarnesses {
    final results = notice?.results;
    if (results == null) return const <HarnessId>[];
    return <HarnessId>[
      for (final result in results)
        if (result.skill.outcome == SkillAutoInstallOutcome.installed)
          result.harnessId,
    ];
  }
}
