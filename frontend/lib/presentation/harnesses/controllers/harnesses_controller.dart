import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'harnesses_state.dart';

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
        state = AsyncData(
          latest.copyWith(
            harnesses: _upsertHarness(latest.harnesses, value),
            refreshingIds: remainingIds,
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
