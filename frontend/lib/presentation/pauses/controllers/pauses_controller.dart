import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pauses_controller.g.dart';

/// Manages the `/pauses` master-detail inbox, selection, response submission,
/// 409 conflict recovery, and live WebSocket updates.
@riverpod
class PausesController extends _$PausesController {
  StreamSubscription<PauseEvent>? _eventsSub;

  @override
  PausesState build() {
    unawaited(_eventsSub?.cancel());
    _eventsSub = ref
        .read(watchPauseEventsUseCaseProvider)()
        .listen(_handlePauseEvent);
    ref.onDispose(() {
      unawaited(_eventsSub?.cancel());
      _eventsSub = null;
    });

    unawaited(Future.microtask(loadPauses));
    return const PausesState();
  }

  /// Loads or refreshes pending pauses from the backend.
  Future<void> loadPauses({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(pauses: const AsyncLoading<List<Pause>>());
    }
    final result = await ref.read(listPendingPausesUseCaseProvider)();
    if (!ref.mounted) return;
    switch (result) {
      case Success<List<Pause>>(:final value):
        final sorted = _sorted(value);
        state = state.copyWith(
          pauses: AsyncData<List<Pause>>(sorted),
          selectedPauseId: () =>
              _resolveSelection(sorted, state.selectedPauseId),
        );
      case FailureResult<List<Pause>>(:final failure):
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

  /// Dismisses any visible conflict or submission error banner.
  void dismissNotice() {
    state = state.copyWith(submitFailure: () => null, hasConflict: false);
  }

  /// Approves or rejects a `humanApproval` pause with optional [feedback].
  Future<bool> submitApproval({
    required String pauseId,
    required bool approved,
    String? feedback,
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
    );

    final result = await ref.read(answerPauseUseCaseProvider)(pauseId, request);
    if (!ref.mounted) return false;

    switch (result) {
      case Success<Pause>(:final value):
        final updatedList = _removePause(
          state.pauses.asData?.value ?? const <Pause>[],
          pauseId,
        );
        state = state.copyWith(
          pauses: AsyncData<List<Pause>>(updatedList),
          selectedPauseId: () =>
              _resolveSelection(updatedList, state.selectedPauseId),
          submittingAction: () => null,
          lastAnnouncement: () => PauseResolvedAnnouncement(value.nodeLabel),
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
        final current = state.pauses.asData?.value;
        if (current == null) {
          unawaited(loadPauses(showLoading: false));
          return;
        }
        final next = _upsertPause(current, pause);
        state = state.copyWith(
          pauses: AsyncData<List<Pause>>(next),
          selectedPauseId: () => _resolveSelection(next, state.selectedPauseId),
          lastAnnouncement: () => PauseArrivedAnnouncement(pause.nodeLabel),
        );
      case PauseResolvedEvent(:final pause):
        final current = state.pauses.asData?.value;
        if (current == null) return;
        final hadPause = current.any((p) => p.id == pause.id);
        if (!hadPause) return;
        final next = _removePause(current, pause.id);
        state = state.copyWith(
          pauses: AsyncData<List<Pause>>(next),
          selectedPauseId: () => _resolveSelection(next, state.selectedPauseId),
          lastAnnouncement: () => PauseResolvedAnnouncement(pause.nodeLabel),
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
