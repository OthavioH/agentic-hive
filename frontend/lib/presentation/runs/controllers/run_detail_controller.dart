import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'run_detail_controller.g.dart';

/// View state for the Run Detail page (`/runs/:id`).
@immutable
final class RunDetailState {
  /// Creates a [RunDetailState].
  const new({
    required this.run,
    required this.events,
    required this.checkpoints,
    this.selectedCheckpointId,
    this.expandedEventIds = const <String>{},
  });

  /// Loaded run metadata and workflow definition.
  final Run run;

  /// Chronological event log entries for [run].
  final List<RunEvent> events;

  /// Saved checkpoints for [run].
  final List<Checkpoint> checkpoints;

  /// ID of the currently inspected checkpoint, or `null` when none exist.
  final String? selectedCheckpointId;

  /// Event IDs whose JSON payload is currently expanded.
  final Set<String> expandedEventIds;

  /// The currently selected [Checkpoint], or `null` if [checkpoints] is empty.
  Checkpoint? get selectedCheckpoint {
    if (checkpoints.isEmpty) return null;
    final id = selectedCheckpointId;
    if (id != null) {
      for (final checkpoint in checkpoints) {
        if (checkpoint.id == id) return checkpoint;
      }
    }
    return checkpoints.last;
  }

  /// Returns a copy with updated fields.
  RunDetailState copyWith({
    Run? run,
    List<RunEvent>? events,
    List<Checkpoint>? checkpoints,
    String? Function()? selectedCheckpointId,
    Set<String>? expandedEventIds,
  }) {
    return RunDetailState(
      run: run ?? this.run,
      events: events ?? this.events,
      checkpoints: checkpoints ?? this.checkpoints,
      selectedCheckpointId: selectedCheckpointId != null
          ? selectedCheckpointId()
          : this.selectedCheckpointId,
      expandedEventIds: expandedEventIds ?? this.expandedEventIds,
    );
  }
}

/// Manages loading and interactive inspection for a single run (`runId`).
@riverpod
class RunDetailController extends _$RunDetailController {
  @override
  Future<RunDetailState> build(String runId) {
    return _load(runId);
  }

  /// Reloads run details, events, and checkpoints from the backend.
  Future<void> refresh() async {
    final previous = state.asData?.value;
    state = const AsyncLoading<RunDetailState>();
    try {
      final loaded = await _load(
        runId,
        preferredCheckpointId: previous?.selectedCheckpointId,
        expandedEventIds: previous?.expandedEventIds ?? const <String>{},
      );
      if (!ref.mounted) return;
      state = AsyncData(loaded);
    } on Failure catch (failure, stackTrace) {
      if (!ref.mounted) return;
      state = AsyncError(failure, stackTrace);
    }
  }

  /// Selects [checkpointId] in the checkpoint inspector.
  void selectCheckpoint(String checkpointId) {
    final current = state.asData?.value;
    if (current == null || current.selectedCheckpointId == checkpointId) return;
    state = AsyncData(
      current.copyWith(selectedCheckpointId: () => checkpointId),
    );
  }

  /// Toggles whether the JSON payload for [eventId] is expanded.
  void toggleEventExpanded(String eventId) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = Set<String>.from(current.expandedEventIds);
    if (!next.add(eventId)) {
      next.remove(eventId);
    }
    state = AsyncData(current.copyWith(expandedEventIds: next));
  }

  Future<RunDetailState> _load(
    String id, {
    String? preferredCheckpointId,
    Set<String> expandedEventIds = const <String>{},
  }) async {
    final runFuture = ref.read(getRunProvider).call(id);
    final eventsFuture = ref.read(getRunEventsProvider).call(id);
    final checkpointsFuture = ref.read(getRunCheckpointsProvider).call(id);

    final runResult = await runFuture;
    final eventsResult = await eventsFuture;
    final checkpointsResult = await checkpointsFuture;

    final run = switch (runResult) {
      Success<Run>(:final value) => value,
      FailureResult<Run>(:final failure) => Error.throwWithStackTrace(
        failure,
        StackTrace.current,
      ),
    };
    final events = switch (eventsResult) {
      Success<RunEventsResponse>(:final value) => value.items,
      FailureResult<RunEventsResponse>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };
    final checkpoints = switch (checkpointsResult) {
      Success<List<Checkpoint>>(:final value) => value,
      FailureResult<List<Checkpoint>>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };

    String? selectedId;
    if (checkpoints.isNotEmpty) {
      if (preferredCheckpointId != null &&
          checkpoints.any((c) => c.id == preferredCheckpointId)) {
        selectedId = preferredCheckpointId;
      } else {
        selectedId = checkpoints
            .reduce((a, b) => a.sequence >= b.sequence ? a : b)
            .id;
      }
    }

    return RunDetailState(
      run: run,
      events: events,
      checkpoints: checkpoints,
      selectedCheckpointId: selectedId,
      expandedEventIds: expandedEventIds,
    );
  }
}
