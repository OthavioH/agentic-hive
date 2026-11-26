import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_state.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/skill_row_models.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'harnesses_state.dart';
export 'skill_row_models.dart';

part 'harnesses_controller.g.dart';

/// Manages the Harnesses page state, refresh actions, and live WebSocket
/// status updates.
@riverpod
class HarnessesController extends _$HarnessesController {
  @override
  Future<HarnessesState> build() async {
    final watchUpdates = ref.watch(watchHarnessUpdatesUseCaseProvider);
    final subscription = watchUpdates().listen(_onHarnessUpdated);
    ref.onDispose(() => unawaited(subscription.cancel()));

    final getHarnesses = ref.watch(getHarnessesUseCaseProvider);
    final result = await getHarnesses();
    return switch (result) {
      Success<List<HarnessInfo>>(:final value) => HarnessesState(
        harnesses: value,
      ),
      FailureResult<List<HarnessInfo>>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };
  }

  /// Re-runs detection for all harnesses, preserving existing cards while the
  /// request is in flight.
  Future<Result<void>> refreshAll() async {
    final current = state.value;
    if (current == null || current.isRefreshingAll) {
      return const Success<void>(null);
    }

    state = AsyncData(current.copyWith(isRefreshingAll: true));

    final result = await ref.read(refreshHarnessesUseCaseProvider)();
    if (!ref.mounted) {
      return const FailureResult<void>(
        UnexpectedFailure('Harnesses controller was disposed.'),
      );
    }

    final latest = state.value ?? current;
    return switch (result) {
      Success<List<HarnessInfo>>(:final value) => () {
        state = AsyncData(
          latest.copyWith(harnesses: value, isRefreshingAll: false),
        );
        return const Success<void>(null);
      }(),
      FailureResult<List<HarnessInfo>>(:final failure) => () {
        state = AsyncData(latest.copyWith(isRefreshingAll: false));
        return FailureResult<void>(failure);
      }(),
    };
  }

  /// Re-runs detection for a single harness [id], showing a loading state only
  /// on that harness's card.
  Future<Result<void>> refreshHarness(HarnessId id) async {
    final current = state.value;
    if (current == null || current.refreshingIds.contains(id)) {
      return const Success<void>(null);
    }

    state = AsyncData(
      current.copyWith(
        refreshingIds: <HarnessId>{...current.refreshingIds, id},
      ),
    );

    final result = await ref.read(refreshHarnessUseCaseProvider)(id);
    if (!ref.mounted) {
      return const FailureResult<void>(
        UnexpectedFailure('Harnesses controller was disposed.'),
      );
    }

    final latest = state.value ?? current;
    final remainingIds = Set<HarnessId>.of(latest.refreshingIds)..remove(id);

    return switch (result) {
      Success<HarnessInfo>(:final value) => () {
        final nextErrors = Map<HarnessId, SkillRowError>.of(latest.skillErrors)
          ..remove(id);
        state = AsyncData(
          latest.copyWith(
            harnesses: _upsertHarness(latest.harnesses, value),
            refreshingIds: remainingIds,
            skillErrors: nextErrors,
          ),
        );
        return const Success<void>(null);
      }(),
      FailureResult<HarnessInfo>(:final failure) => () {
        state = AsyncData(latest.copyWith(refreshingIds: remainingIds));
        return FailureResult<void>(failure);
      }(),
    };
  }

  /// Installs or updates the Hive MCP server for a single harness [id],
  /// showing a loading state only on that harness's card.
  Future<Result<void>> installMcp(HarnessId id) async {
    final current = state.value;
    if (current == null || current.installingMcpIds.contains(id)) {
      return const Success<void>(null);
    }

    state = AsyncData(
      current.copyWith(
        installingMcpIds: <HarnessId>{...current.installingMcpIds, id},
      ),
    );

    final result = await ref.read(installHarnessMcpUseCaseProvider)(id);
    if (!ref.mounted) {
      return const FailureResult<void>(
        UnexpectedFailure('Harnesses controller was disposed.'),
      );
    }

    final latest = state.value ?? current;
    final remainingIds = Set<HarnessId>.of(latest.installingMcpIds)..remove(id);

    return switch (result) {
      Success<HarnessInfo>(:final value) => () {
        state = AsyncData(
          latest.copyWith(
            harnesses: _upsertHarness(latest.harnesses, value),
            installingMcpIds: remainingIds,
          ),
        );
        return const Success<void>(null);
      }(),
      FailureResult<HarnessInfo>(:final failure) => () {
        state = AsyncData(latest.copyWith(installingMcpIds: remainingIds));
        return FailureResult<void>(failure);
      }(),
    };
  }

  /// Installs or updates the Agentic Hive skill for a single harness [id].
  Future<Result<void>> installSkill(
    HarnessId id, {
    required SkillRowAction action,
    bool overwriteModified = false,
  }) => _runSkillAction(
    id,
    action: action,
    overwriteModified: overwriteModified,
    run: () => ref.read(installHarnessSkillUseCaseProvider)(
      id,
      overwriteModified: overwriteModified,
    ),
  );

  /// Removes the Agentic Hive skill for a single harness [id].
  Future<Result<void>> removeSkill(HarnessId id) => _runSkillAction(
    id,
    action: SkillRowAction.remove,
    overwriteModified: false,
    run: () => ref.read(removeHarnessSkillUseCaseProvider)(id),
  );

  /// Clears any stored skill row error for [id].
  void clearSkillError(HarnessId id) {
    final current = state.value;
    if (current == null || !current.skillErrors.containsKey(id)) return;
    final nextErrors = Map<HarnessId, SkillRowError>.of(current.skillErrors)
      ..remove(id);
    state = AsyncData(current.copyWith(skillErrors: nextErrors));
  }

  Future<Result<void>> _runSkillAction(
    HarnessId id, {
    required SkillRowAction action,
    required bool overwriteModified,
    required Future<Result<HarnessInfo>> Function() run,
  }) async {
    final current = state.value;
    if (current == null || current.skillActions.containsKey(id)) {
      return const Success<void>(null);
    }

    final startingErrors = Map<HarnessId, SkillRowError>.of(current.skillErrors)
      ..remove(id);
    state = AsyncData(
      current.copyWith(
        skillActions: <HarnessId, SkillRowAction>{
          ...current.skillActions,
          id: action,
        },
        skillErrors: startingErrors,
      ),
    );

    final result = await run();
    if (!ref.mounted) {
      return const FailureResult<void>(
        UnexpectedFailure('Harnesses controller was disposed.'),
      );
    }

    final latest = state.value ?? current;
    final remainingActions = Map<HarnessId, SkillRowAction>.of(
      latest.skillActions,
    )..remove(id);

    return switch (result) {
      Success<HarnessInfo>(:final value) => () {
        state = AsyncData(
          latest.copyWith(
            harnesses: _upsertHarness(latest.harnesses, value),
            skillActions: remainingActions,
          ),
        );
        return const Success<void>(null);
      }(),
      FailureResult<HarnessInfo>(:final failure) => () {
        final nextErrors = Map<HarnessId, SkillRowError>.of(latest.skillErrors)
          ..[id] = SkillRowError(
            failure: failure,
            action: action,
            overwriteModified: overwriteModified,
          );
        state = AsyncData(
          latest.copyWith(
            skillActions: remainingActions,
            skillErrors: nextErrors,
          ),
        );
        return FailureResult<void>(failure);
      }(),
    };
  }

  void _onHarnessUpdated(HarnessInfo updated) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(harnesses: _upsertHarness(current.harnesses, updated)),
    );
  }

  List<HarnessInfo> _upsertHarness(
    List<HarnessInfo> existing,
    HarnessInfo updated,
  ) {
    var replaced = false;
    final next = <HarnessInfo>[
      for (final item in existing)
        if (item.id == updated.id)
          () {
            replaced = true;
            return updated;
          }()
        else
          item,
    ];
    if (!replaced) {
      next.add(updated);
    }
    return next;
  }
}

/// Maps each headless harness node type ID (`harness.<wireName>`) to its
/// latest detected [HarnessStatus], or `null` while loading or on error.
@riverpod
Map<String, HarnessStatus>? harnessStatusByTypeId(Ref ref) {
  final harnesses = ref
      .watch(harnessesControllerProvider)
      .asData
      ?.value
      .harnesses;
  if (harnesses == null) return null;
  return <String, HarnessStatus>{
    for (final info in harnesses) 'harness.${info.id.wireName}': info.status,
  };
}
