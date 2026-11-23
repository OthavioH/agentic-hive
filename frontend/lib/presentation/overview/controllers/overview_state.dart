import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-flight inline pause decision action on an Overview pause card.
enum OverviewPauseAction {
  /// Approving a simple `human_approval` pause.
  approve,

  /// Rejecting a simple `human_approval` pause.
  reject,
}

/// View state for the `/overview` operational dashboard.
@immutable
final class OverviewState {
  /// Creates an [OverviewState].
  const new({
    required this.snapshot,
    this.isRefreshing = false,
    this.refreshFailure,
    this.submittingPauses = const <String, OverviewPauseAction>{},
    this.pauseErrors = const <String, Failure>{},
    this.hasPendingPausesChanged = false,
  });

  /// Current aggregate operational snapshot.
  final AsyncValue<OverviewSnapshot> snapshot;

  /// Whether a background refresh is in flight while keeping existing data.
  final bool isRefreshing;

  /// Non-fatal failure from a background refresh when cached data exists.
  final Failure? refreshFailure;

  /// Map of `pauseId` to the inline decision currently in flight.
  final Map<String, OverviewPauseAction> submittingPauses;

  /// Map of `pauseId` to the latest inline approval/rejection failure.
  final Map<String, Failure> pauseErrors;

  /// Whether `metrics.pendingPausesCount` has changed since the first loaded
  /// snapshot, used to gate the accessibility live region so it does not
  /// announce on first build.
  final bool hasPendingPausesChanged;

  /// Returns the in-flight action for [pauseId], or `null` when idle.
  OverviewPauseAction? submittingActionFor(String pauseId) =>
      submittingPauses[pauseId];

  /// Returns the inline error for [pauseId], or `null` when none.
  Failure? errorForPause(String pauseId) => pauseErrors[pauseId];

  /// Returns a copy with updated fields.
  OverviewState copyWith({
    AsyncValue<OverviewSnapshot>? snapshot,
    bool? isRefreshing,
    Failure? Function()? refreshFailure,
    Map<String, OverviewPauseAction>? submittingPauses,
    Map<String, Failure>? pauseErrors,
    bool? hasPendingPausesChanged,
  }) {
    return OverviewState(
      snapshot: snapshot ?? this.snapshot,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFailure: refreshFailure != null
          ? refreshFailure()
          : this.refreshFailure,
      submittingPauses: submittingPauses ?? this.submittingPauses,
      pauseErrors: pauseErrors ?? this.pauseErrors,
      hasPendingPausesChanged:
          hasPendingPausesChanged ?? this.hasPendingPausesChanged,
    );
  }
}
