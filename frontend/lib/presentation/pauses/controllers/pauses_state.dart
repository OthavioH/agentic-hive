import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which submission action is currently in flight for the selected pause.
enum PauseSubmittingAction {
  /// Approving a `humanApproval` pause.
  approve,

  /// Rejecting a `humanApproval` pause.
  reject,

  /// Submitting an `askHuman` answer.
  answer,
}

/// Live-region announcement kind for screen readers.
sealed class PauseAnnouncement {
  /// Creates a [PauseAnnouncement].
  const new();
}

/// Announces that a new pause arrived.
final class PauseArrivedAnnouncement extends PauseAnnouncement {
  /// Creates a [PauseArrivedAnnouncement].
  const new(this.nodeLabel);

  /// Label of the newly created pause's node.
  final String nodeLabel;
}

/// Announces that an existing pause was resolved or cancelled remotely.
final class PauseResolvedAnnouncement extends PauseAnnouncement {
  /// Creates a [PauseResolvedAnnouncement].
  const new(this.nodeLabel);

  /// Label of the resolved pause's node.
  final String nodeLabel;
}

/// Immutable view state for the Pauses inbox (`/pauses`).
final class PausesState {
  /// Creates a [PausesState].
  const new({
    this.pauses = const AsyncLoading<List<Pause>>(),
    this.selectedPauseId,
    this.submittingAction,
    this.submitFailure,
    this.hasConflict = false,
    this.remoteResolvedNodeLabel,
    this.lastAnnouncement,
    this.feedbackDrafts = const <String, String>{},
    this.answerDrafts = const <String, String>{},
    this.now,
  });

  /// Pending pauses list state.
  final AsyncValue<List<Pause>> pauses;

  /// Currently selected pause ID in the master list.
  final String? selectedPauseId;

  /// In-flight submission action, or `null` when idle.
  final PauseSubmittingAction? submittingAction;

  /// Last non-conflict submission failure, if any.
  final Failure? submitFailure;

  /// Whether the last submission failed with HTTP 409 conflict.
  final bool hasConflict;

  /// Node label of the selected pause when it was resolved/cancelled remotely,
  /// shown as an explicit notice banner so drafts/context are not silently lost.
  final String? remoteResolvedNodeLabel;

  /// Latest live-region announcement for screen readers.
  final PauseAnnouncement? lastAnnouncement;

  /// Preserved optional feedback drafts keyed by pause ID.
  final Map<String, String> feedbackDrafts;

  /// Preserved answer drafts keyed by pause ID.
  final Map<String, String> answerDrafts;

  /// Reference timestamp updated periodically to refresh relative waiting
  /// times.
  final DateTime? now;

  /// Whether a response submission is currently in flight.
  bool get isSubmitting => submittingAction != null;

  /// Returns the preserved feedback draft for [pauseId].
  String feedbackDraftFor(String pauseId) => feedbackDrafts[pauseId] ?? '';

  /// Returns the preserved answer draft for [pauseId].
  String answerDraftFor(String pauseId) => answerDrafts[pauseId] ?? '';

  /// Returns the currently selected [Pause], or `null` if none is selected.
  Pause? get selectedPause {
    final items = pauses.asData?.value;
    if (items == null || items.isEmpty) return null;
    final id = selectedPauseId;
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Returns a copy of this state with the given fields replaced.
  PausesState copyWith({
    AsyncValue<List<Pause>>? pauses,
    String? Function()? selectedPauseId,
    PauseSubmittingAction? Function()? submittingAction,
    Failure? Function()? submitFailure,
    bool? hasConflict,
    String? Function()? remoteResolvedNodeLabel,
    PauseAnnouncement? Function()? lastAnnouncement,
    Map<String, String>? feedbackDrafts,
    Map<String, String>? answerDrafts,
    DateTime? now,
  }) {
    return PausesState(
      pauses: pauses ?? this.pauses,
      selectedPauseId: selectedPauseId != null
          ? selectedPauseId()
          : this.selectedPauseId,
      submittingAction: submittingAction != null
          ? submittingAction()
          : this.submittingAction,
      submitFailure: submitFailure != null
          ? submitFailure()
          : this.submitFailure,
      hasConflict: hasConflict ?? this.hasConflict,
      remoteResolvedNodeLabel: remoteResolvedNodeLabel != null
          ? remoteResolvedNodeLabel()
          : this.remoteResolvedNodeLabel,
      lastAnnouncement: lastAnnouncement != null
          ? lastAnnouncement()
          : this.lastAnnouncement,
      feedbackDrafts: feedbackDrafts ?? this.feedbackDrafts,
      answerDrafts: answerDrafts ?? this.answerDrafts,
      now: now ?? this.now,
    );
  }
}
