import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pauses_controller.g.dart';

/// Clock and periodic timer configuration for [PausesController], injectable
/// in tests via [pausesClockConfigProvider].
final class PausesClockConfig {
  /// Creates a [PausesClockConfig] with production defaults.
  const new({
    this.now = _defaultNow,
    this.createPeriodicTimer = Timer.periodic,
    this.refreshInterval = defaultRefreshInterval,
  });

  static const int _refreshMinutes = 1;

  /// Default 1-minute tick interval for relative waiting-time labels.
  static const Duration defaultRefreshInterval = Duration(
    minutes: _refreshMinutes,
  );

  static DateTime _defaultNow() => DateTime.now().toUtc();

  /// Returns the current timestamp.
  final DateTime Function() now;

  /// Creates a periodic [Timer] that fires every [refreshInterval].
  final Timer Function(Duration duration, void Function(Timer) callback)
  createPeriodicTimer;

  /// Interval between relative waiting-time refreshes.
  final Duration refreshInterval;
}

/// Provides [PausesClockConfig] for [PausesController].
@Riverpod(keepAlive: true)
PausesClockConfig pausesClockConfig(Ref ref) => const PausesClockConfig();

/// Manages the `/pauses` master-detail inbox, selection, per-pause drafts,
/// response submission, 409 conflict recovery, and live WebSocket updates.
@riverpod
class PausesController extends _$PausesController {
  StreamSubscription<PauseEvent>? _eventsSub;
  Timer? _clockTimer;
  int _inFlightLoads = 0;
  final Map<String, Pause> _createdDuringLoad = <String, Pause>{};
  final Set<String> _resolvedDuringLoad = <String>{};
  final Set<String> _locallySubmittedIds = <String>{};

  @override
  PausesState build() {
    unawaited(_eventsSub?.cancel());
    _clockTimer?.cancel();
    _inFlightLoads = 0;
    _createdDuringLoad.clear();
    _resolvedDuringLoad.clear();
    _locallySubmittedIds.clear();

    final clock = ref.watch(pausesClockConfigProvider);
    _eventsSub = ref
        .read(watchPauseEventsUseCaseProvider)()
        .listen(_handlePauseEvent);
    _clockTimer = clock.createPeriodicTimer(clock.refreshInterval, (_) {
      if (!ref.mounted) return;
      state = state.copyWith(now: clock.now());
    });

    ref.onDispose(() {
      unawaited(_eventsSub?.cancel());
      _eventsSub = null;
      _clockTimer?.cancel();
      _clockTimer = null;
    });

    unawaited(Future.microtask(loadPauses));
    return PausesState(now: clock.now());
  }

  /// Loads or refreshes pending pauses from the backend.
  ///
  /// When [showLoading] is `false` (silent reconnect or background refresh),
  /// any previously loaded list is preserved on failure instead of replacing
  /// the inbox with an error screen.
  Future<void> loadPauses({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(pauses: const AsyncLoading<List<Pause>>());
    }
    _inFlightLoads++;
    final result = await ref.read(listPendingPausesUseCaseProvider)();
    _inFlightLoads--;
    if (!ref.mounted) return;

    switch (result) {
      case Success<List<Pause>>(:final value):
        final mergedById = <String, Pause>{
          for (final pause in value)
            if (pause.status == PauseStatus.pending &&
                !_resolvedDuringLoad.contains(pause.id))
              pause.id: pause,
          ..._createdDuringLoad,
        };
        if (_inFlightLoads == 0) {
          _createdDuringLoad.clear();
          _resolvedDuringLoad.clear();
        }
        final sorted = _sorted(mergedById.values.toList());
        state = state.copyWith(
          pauses: AsyncData<List<Pause>>(sorted),
          selectedPauseId: () =>
              _resolveSelection(sorted, state.selectedPauseId),
        );
      case FailureResult<List<Pause>>(:final failure):
        if (_inFlightLoads == 0) {
          _createdDuringLoad.clear();
          _resolvedDuringLoad.clear();
        }
        if (!showLoading && state.pauses.hasValue) {
          return;
        }
        state = state.copyWith(
          pauses: AsyncError<List<Pause>>(failure, StackTrace.current),
        );
    }
  }

  /// Selects a pause in the master list by [pauseId].
  void selectPause(String pauseId) {
    if (state.selectedPauseId == pauseId) return;
    state = state.copyWith(
      selectedPauseId: () => pauseId,
      submitFailure: () => null,
      hasConflict: false,
    );
  }

  /// Updates the saved optional feedback draft for [pauseId].
  void updateFeedbackDraft(String pauseId, String feedback) {
    if (state.feedbackDraftFor(pauseId) == feedback) return;
    state = state.copyWith(
      feedbackDrafts: <String, String>{
        ...state.feedbackDrafts,
        pauseId: feedback,
      },
    );
  }

  /// Updates the saved answer draft for [pauseId].
  void updateAnswerDraft(String pauseId, String answer) {
    if (state.answerDraftFor(pauseId) == answer) return;
    state = state.copyWith(
      answerDrafts: <String, String>{...state.answerDrafts, pauseId: answer},
    );
  }

  /// Starts editing the proposal for [pauseId], seeded with [initialText].
  ///
  /// Does nothing when [pauseId] is already in editing mode.
  void startProposalEdit(String pauseId, String initialText) {
    if (state.isEditingProposal(pauseId)) return;
    state = state.copyWith(
      proposalDrafts: <String, String>{
        ...state.proposalDrafts,
        pauseId: initialText,
      },
    );
  }

  /// Updates the saved proposal JSON draft for [pauseId] while editing.
  void updateProposalDraft(String pauseId, String text) {
    if (!state.isEditingProposal(pauseId)) return;
    if (state.proposalDraftFor(pauseId) == text) return;
    state = state.copyWith(
      proposalDrafts: <String, String>{...state.proposalDrafts, pauseId: text},
    );
  }

  /// Discards any edited proposal draft for [pauseId] and exits edit mode.
  void discardProposalEdit(String pauseId) {
    if (!state.isEditingProposal(pauseId)) return;
    final next = Map<String, String>.from(state.proposalDrafts)
      ..remove(pauseId);
    state = state.copyWith(proposalDrafts: next);
  }

  /// Clears the live-region announcement after it has been rendered so that
  /// identical consecutive announcements fire again.
  void clearAnnouncement() {
    if (state.lastAnnouncement == null) return;
    state = state.copyWith(lastAnnouncement: () => null);
  }

  /// Dismisses any visible conflict, remote-resolution, or error banner.
  void dismissNotice() {
    state = state.copyWith(
      submitFailure: () => null,
      hasConflict: false,
      remoteResolvedNodeLabel: () => null,
    );
  }

  /// Approves or rejects a `humanApproval` pause with optional [feedback] and
  /// edited [proposal] when [approved] is `true`.
  Future<bool> submitApproval({
    required String pauseId,
    required bool approved,
    String? feedback,
    Object? proposal,
  }) {
    final trimmedFeedback = feedback?.trim();
    return _submit(
      pauseId: pauseId,
      action: approved
          ? PauseSubmittingAction.approve
          : PauseSubmittingAction.reject,
      request: AnswerPauseRequest(
        decision: approved ? 'approved' : 'rejected',
        feedback: (trimmedFeedback != null && trimmedFeedback.isNotEmpty)
            ? trimmedFeedback
            : null,
        proposal: approved ? proposal : null,
      ),
    );
  }

  /// Submits a free-text [answer] for an `askHuman` pause.
  Future<bool> submitAnswer({required String pauseId, required String answer}) {
    return _submit(
      pauseId: pauseId,
      action: PauseSubmittingAction.answer,
      request: AnswerPauseRequest(answer: answer.trim()),
    );
  }

  Future<bool> _submit({
    required String pauseId,
    required PauseSubmittingAction action,
    required AnswerPauseRequest request,
  }) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(
      submittingAction: () => action,
      submitFailure: () => null,
      hasConflict: false,
      remoteResolvedNodeLabel: () => null,
    );

    final result = await ref.read(answerPauseUseCaseProvider)(pauseId, request);
    if (!ref.mounted) return false;

    switch (result) {
      case Success<Pause>():
        _locallySubmittedIds.add(pauseId);
        if (_inFlightLoads > 0) {
          _resolvedDuringLoad.add(pauseId);
          _createdDuringLoad.remove(pauseId);
        }
        final updatedList = _removePause(
          state.pauses.asData?.value ?? const <Pause>[],
          pauseId,
        );
        final nextFeedbackDrafts = Map<String, String>.from(
          state.feedbackDrafts,
        )..remove(pauseId);
        final nextAnswerDrafts = Map<String, String>.from(state.answerDrafts)
          ..remove(pauseId);
        final nextProposalDrafts = Map<String, String>.from(
          state.proposalDrafts,
        )..remove(pauseId);
        state = state.copyWith(
          pauses: AsyncData<List<Pause>>(updatedList),
          selectedPauseId: () =>
              _resolveSelection(updatedList, state.selectedPauseId),
          submittingAction: () => null,
          feedbackDrafts: nextFeedbackDrafts,
          answerDrafts: nextAnswerDrafts,
          proposalDrafts: nextProposalDrafts,
        );
        return true;
      case FailureResult<Pause>(:final failure):
        final isConflict =
            failure is ConflictFailure ||
            (failure is BackendFailure && failure.statusCode == 409);
        if (isConflict) {
          state = state.copyWith(
            submittingAction: () => null,
            hasConflict: true,
            submitFailure: () => null,
          );
          await loadPauses(showLoading: false);
          return false;
        }
        state = state.copyWith(
          submittingAction: () => null,
          submitFailure: () => failure,
        );
        return false;
    }
  }

  void _handlePauseEvent(PauseEvent event) {
    if (!ref.mounted) return;
    switch (event) {
      case PauseCreatedEvent(:final pause):
        if (pause.status != PauseStatus.pending) return;
        if (_inFlightLoads > 0) {
          _createdDuringLoad[pause.id] = pause;
          _resolvedDuringLoad.remove(pause.id);
        }
        final current = state.pauses.asData?.value;
        if (current == null) {
          state = state.copyWith(
            lastAnnouncement: () => PauseArrivedAnnouncement(pause.nodeLabel),
          );
          if (_inFlightLoads == 0) {
            unawaited(loadPauses(showLoading: false));
          }
          return;
        }
        final next = _upsertPause(current, pause);
        state = state.copyWith(
          pauses: AsyncData<List<Pause>>(next),
          selectedPauseId: () => _resolveSelection(next, state.selectedPauseId),
          lastAnnouncement: () => PauseArrivedAnnouncement(pause.nodeLabel),
        );
      case PauseResolvedEvent(:final pause):
        final wasLocalSubmit = _locallySubmittedIds.remove(pause.id);
        if (_inFlightLoads > 0) {
          _resolvedDuringLoad.add(pause.id);
          _createdDuringLoad.remove(pause.id);
        }
        final current = state.pauses.asData?.value;
        if (current == null) return;
        final hadPause = current.any((p) => p.id == pause.id);
        if (!hadPause) return;
        final wasSelected = state.selectedPauseId == pause.id;
        final next = _removePause(current, pause.id);
        final nextFeedbackDrafts = Map<String, String>.from(
          state.feedbackDrafts,
        )..remove(pause.id);
        final nextAnswerDrafts = Map<String, String>.from(state.answerDrafts)
          ..remove(pause.id);
        final nextProposalDrafts = Map<String, String>.from(
          state.proposalDrafts,
        )..remove(pause.id);
        state = state.copyWith(
          pauses: AsyncData<List<Pause>>(next),
          selectedPauseId: () => _resolveSelection(next, state.selectedPauseId),
          feedbackDrafts: nextFeedbackDrafts,
          answerDrafts: nextAnswerDrafts,
          proposalDrafts: nextProposalDrafts,
          remoteResolvedNodeLabel: () => (!wasLocalSubmit && wasSelected)
              ? pause.nodeLabel
              : state.remoteResolvedNodeLabel,
          lastAnnouncement: () => wasLocalSubmit
              ? state.lastAnnouncement
              : PauseResolvedAnnouncement(pause.nodeLabel),
        );
      case PauseSyncRequestedEvent():
        unawaited(loadPauses(showLoading: false));
    }
  }

  List<Pause> _sorted(List<Pause> items) {
    final copy = List<Pause>.from(items)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return copy;
  }

  List<Pause> _upsertPause(List<Pause> current, Pause pause) {
    final next = current.where((p) => p.id != pause.id).toList()..add(pause);
    return _sorted(next);
  }

  List<Pause> _removePause(List<Pause> current, String pauseId) {
    return current.where((p) => p.id != pauseId).toList();
  }

  String? _resolveSelection(List<Pause> items, String? currentSelection) {
    if (items.isEmpty) return null;
    if (currentSelection != null &&
        items.any((p) => p.id == currentSelection)) {
      return currentSelection;
    }
    return items.first.id;
  }
}
