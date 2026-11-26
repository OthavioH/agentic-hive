import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'snapshots_controller.g.dart';

/// Load state of the changed-file list of one snapshot.
@immutable
sealed class SnapshotDiffState {
  const new();
}

/// The changed-file list is being fetched.
final class SnapshotDiffLoading extends SnapshotDiffState {
  /// Creates a loading diff state.
  const new();
}

/// The changed-file list was fetched.
final class SnapshotDiffLoaded extends SnapshotDiffState {
  /// Creates a loaded diff state.
  const new(this.files);

  /// Files changed in the snapshot.
  final List<SnapshotFileChange> files;
}

/// Fetching the changed-file list failed.
final class SnapshotDiffFailed extends SnapshotDiffState {
  /// Creates a failed diff state.
  const new(this.failure);

  /// Why the fetch failed.
  final Failure failure;
}

/// View state for the Snapshots panel of the Run Detail page.
@immutable
final class SnapshotsState {
  /// Creates a [SnapshotsState].
  const new({
    required this.snapshots,
    required this.capabilities,
    this.expandedSnapshotIds = const <String>{},
    this.diffs = const <String, SnapshotDiffState>{},
    this.restoringSnapshotId,
    this.restoreFailure,
  });

  /// Snapshots of the run, oldest first.
  final List<Snapshot> snapshots;

  /// Result of the workspace capability check used to gate restore.
  final Result<WorkspaceCapabilities> capabilities;

  /// IDs of snapshots whose changed-file list is expanded.
  final Set<String> expandedSnapshotIds;

  /// Changed-file lists by snapshot ID, for expanded snapshots.
  final Map<String, SnapshotDiffState> diffs;

  /// ID of the snapshot being restored, or `null` when idle.
  final String? restoringSnapshotId;

  /// Failure from the last restore attempt, or `null`.
  final Failure? restoreFailure;

  /// Returns a copy with updated fields.
  SnapshotsState copyWith({
    List<Snapshot>? snapshots,
    Result<WorkspaceCapabilities>? capabilities,
    Set<String>? expandedSnapshotIds,
    Map<String, SnapshotDiffState>? diffs,
    String? Function()? restoringSnapshotId,
    Failure? Function()? restoreFailure,
  }) {
    return SnapshotsState(
      snapshots: snapshots ?? this.snapshots,
      capabilities: capabilities ?? this.capabilities,
      expandedSnapshotIds: expandedSnapshotIds ?? this.expandedSnapshotIds,
      diffs: diffs ?? this.diffs,
      restoringSnapshotId: restoringSnapshotId != null
          ? restoringSnapshotId()
          : this.restoringSnapshotId,
      restoreFailure: restoreFailure != null
          ? restoreFailure()
          : this.restoreFailure,
    );
  }
}

/// Loads, inspects and restores the snapshots of one run.
@riverpod
class SnapshotsController extends _$SnapshotsController {
  @override
  Future<SnapshotsState> build(String runId, String workspaceRoot) {
    return _load();
  }

  /// Reloads snapshots and capabilities from the backend.
  Future<void> refresh() async {
    try {
      final loaded = await _load();
      if (!ref.mounted) return;
      final previous = state.asData?.value;
      state = AsyncData(
        previous == null
            ? loaded
            : loaded.copyWith(
                expandedSnapshotIds: previous.expandedSnapshotIds,
                diffs: previous.diffs,
              ),
      );
    } on Failure catch (failure, stackTrace) {
      if (!ref.mounted) return;
      state = AsyncError(failure, stackTrace);
    }
  }

  /// Expands or collapses the changed-file list of [snapshotId], fetching it
  /// the first time.
  Future<void> toggleExpanded(String snapshotId) async {
    final current = state.asData?.value;
    if (current == null) return;
    final expanded = Set<String>.from(current.expandedSnapshotIds);
    if (!expanded.add(snapshotId)) {
      expanded.remove(snapshotId);
      state = AsyncData(current.copyWith(expandedSnapshotIds: expanded));
      return;
    }
    final existing = current.diffs[snapshotId];
    if (existing is SnapshotDiffLoaded || existing is SnapshotDiffLoading) {
      state = AsyncData(current.copyWith(expandedSnapshotIds: expanded));
      return;
    }
    state = AsyncData(
      current.copyWith(
        expandedSnapshotIds: expanded,
        diffs: <String, SnapshotDiffState>{
          ...current.diffs,
          snapshotId: const SnapshotDiffLoading(),
        },
      ),
    );
    final result = await ref
        .read(getSnapshotDiffProvider)
        .call(runId, snapshotId);
    if (!ref.mounted) return;
    final latest = state.asData?.value;
    if (latest == null) return;
    final diffState = switch (result) {
      Success<SnapshotDiff>(:final value) => SnapshotDiffLoaded(value.files),
      FailureResult<SnapshotDiff>(:final failure) => SnapshotDiffFailed(
        failure,
      ),
    };
    state = AsyncData(
      latest.copyWith(
        diffs: <String, SnapshotDiffState>{
          ...latest.diffs,
          snapshotId: diffState,
        },
      ),
    );
  }

  /// Restores the workspace to [snapshotId]; returns whether it succeeded.
  ///
  /// On success the snapshots and the run's events are refreshed; on failure
  /// [SnapshotsState.restoreFailure] is set.
  Future<bool> restore(String snapshotId) async {
    final current = state.asData?.value;
    if (current == null || current.restoringSnapshotId != null) return false;
    state = AsyncData(
      current.copyWith(
        restoringSnapshotId: () => snapshotId,
        restoreFailure: () => null,
      ),
    );
    final result = await ref
        .read(restoreSnapshotProvider)
        .call(runId, snapshotId);
    if (!ref.mounted) return false;
    switch (result) {
      case Success<RestoreSnapshotResponse>():
        final snapshotsResult = await ref
            .read(listRunSnapshotsProvider)
            .call(runId);
        if (!ref.mounted) return false;
        final latest = state.asData?.value ?? current;
        state = AsyncData(
          latest.copyWith(
            snapshots: snapshotsResult.valueOrNull,
            restoringSnapshotId: () => null,
            restoreFailure: () => null,
          ),
        );
        await ref.read(runDetailControllerProvider(runId).notifier).refresh();
        return true;
      case FailureResult<RestoreSnapshotResponse>(:final failure):
        final latest = state.asData?.value ?? current;
        state = AsyncData(
          latest.copyWith(
            restoringSnapshotId: () => null,
            restoreFailure: () => failure,
          ),
        );
        return false;
    }
  }

  /// Clears the last restore failure.
  void dismissRestoreFailure() {
    final current = state.asData?.value;
    if (current == null || current.restoreFailure == null) return;
    state = AsyncData(current.copyWith(restoreFailure: () => null));
  }

  Future<SnapshotsState> _load() async {
    final snapshotsFuture = ref.read(listRunSnapshotsProvider).call(runId);
    final capabilitiesFuture = ref
        .read(getWorkspaceCapabilitiesProvider)
        .call(path: workspaceRoot);
    final snapshotsResult = await snapshotsFuture;
    final capabilities = await capabilitiesFuture;
    final snapshots = switch (snapshotsResult) {
      Success<List<Snapshot>>(:final value) => value,
      FailureResult<List<Snapshot>>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };
    return SnapshotsState(snapshots: snapshots, capabilities: capabilities);
  }
}
