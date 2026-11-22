import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_event.dart';
import 'package:agentic_hive_frontend/presentation/overview/controllers/overview_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overview_controller.g.dart';

/// Clock, timer, and debounce configuration for [OverviewController],
/// injectable in tests via [overviewClockConfigProvider].
final class OverviewClockConfig {
  /// Creates an [OverviewClockConfig] with production defaults.
  const new({
    this.now = _defaultNow,
    this.createPeriodicTimer = Timer.periodic,
    this.createOneShotTimer = Timer.new,
    this.tickInterval = defaultTickInterval,
    this.resyncDebounce = defaultResyncDebounce,
  });

  static const int _tickSeconds = 1;
  static const int _resyncDebounceMs = 150;

  /// Default 1-second tick interval for live elapsed durations.
  static const Duration defaultTickInterval = Duration(seconds: _tickSeconds);

  /// Default debounce window for coalescing bursty WebSocket events.
  static const Duration defaultResyncDebounce = Duration(
    milliseconds: _resyncDebounceMs,
  );

  static DateTime _defaultNow() => DateTime.now().toUtc();

  /// Returns the current timestamp.
  final DateTime Function() now;

  /// Creates a periodic [Timer] that fires every [tickInterval].
  final Timer Function(Duration duration, void Function(Timer) callback)
  createPeriodicTimer;

  /// Creates a one-shot [Timer] for debounced snapshot resyncs.
  final Timer Function(Duration duration, void Function() callback)
  createOneShotTimer;

  /// Interval between local elapsed-duration UI ticks.
  final Duration tickInterval;

  /// Debounce duration for coalescing WebSocket-triggered snapshot resyncs.
  final Duration resyncDebounce;
}

/// Provides [OverviewClockConfig] for [OverviewController] and [OverviewNow].
@Riverpod(keepAlive: true)
OverviewClockConfig overviewClockConfig(Ref ref) => const OverviewClockConfig();

/// Provides the current UTC timestamp for live elapsed-duration widgets on
/// `/overview`.
///
/// The 1-second periodic timer runs only while active runs or active nodes
/// exist and is cancelled in `ref.onDispose`.
@riverpod
class OverviewNow extends _$OverviewNow {
  Timer? _timer;
  bool _isActive = false;

  @override
  DateTime build() {
    _timer?.cancel();
    _timer = null;
    _isActive = false;
    final clock = ref.watch(overviewClockConfigProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _isActive = false;
    });
    return clock.now();
  }

  /// Starts or stops the 1-second periodic ticker based on [hasActive].
  void setActive({required bool hasActive}) {
    if (_isActive == hasActive) return;
    _isActive = hasActive;
    if (hasActive) {
      final clock = ref.read(overviewClockConfigProvider);
      state = clock.now();
      _timer?.cancel();
      _timer = clock.createPeriodicTimer(clock.tickInterval, (_) {
        if (!ref.mounted) return;
        state = ref.read(overviewClockConfigProvider).now();
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// Manages the `/overview` operational dashboard: initial snapshot load,
/// live WebSocket updates (`run.*`, `node.*`, `pause.*`) and reconnect resync,
/// and inline simple pause approvals/rejections.
@riverpod
class OverviewController extends _$OverviewController {
  StreamSubscription<OverviewEvent>? _eventsSub;
  Timer? _resyncTimer;
  int _loadToken = 0;
  int _eventEpoch = 0;
  int? _initialPendingPausesCount;

  OverviewClockConfig get _clock => ref.read(overviewClockConfigProvider);

  @override
  OverviewState build() {
    unawaited(_eventsSub?.cancel());
    _resyncTimer?.cancel();
    _resyncTimer = null;
    _loadToken = 0;
    _eventEpoch = 0;
    _initialPendingPausesCount = null;

    ref.watch(overviewClockConfigProvider);
    ref.listen(overviewNowProvider, (_, _) {});
    _eventsSub = ref
        .read(watchOverviewEventsUseCaseProvider)()
        .listen(_handleOverviewEvent);

    ref.onDispose(() {
      unawaited(_eventsSub?.cancel());
      _eventsSub = null;
      _resyncTimer?.cancel();
      _resyncTimer = null;
    });

    unawaited(Future.microtask(loadOverview));
    return const OverviewState(snapshot: AsyncLoading<OverviewSnapshot>());
  }

  /// Fetches the latest [OverviewSnapshot] from the backend.
  ///
  /// When [showLoading] is `false` and a snapshot is already loaded, existing
  /// data stays visible while refreshing and any failure is surfaced via
  /// [OverviewState.refreshFailure] instead of replacing the dashboard.
  Future<void> loadOverview({bool showLoading = true}) async {
    final token = ++_loadToken;
    final startEpoch = _eventEpoch;
    final hasExistingData = state.snapshot.hasValue;
    if (showLoading && !hasExistingData) {
      state = state.copyWith(
        snapshot: const AsyncLoading<OverviewSnapshot>(),
        isRefreshing: false,
        refreshFailure: () => null,
      );
    } else {
      state = state.copyWith(isRefreshing: true, refreshFailure: () => null);
    }

    final result = await ref.read(getOverviewUseCaseProvider)();
    if (!ref.mounted || token != _loadToken) return;
    if (_eventEpoch != startEpoch) {
      unawaited(
        loadOverview(showLoading: showLoading && !state.snapshot.hasValue),
      );
      return;
    }

    switch (result) {
      case Success<OverviewSnapshot>(:final value):
        state = state.copyWith(
          snapshot: AsyncData<OverviewSnapshot>(value),
          isRefreshing: false,
          refreshFailure: () => null,
          hasPendingPausesChanged: _trackPendingPausesChanged(value),
        );
        _syncElapsedTimer(value);
      case FailureResult<OverviewSnapshot>(:final failure):
        if (!showLoading && hasExistingData) {
          state = state.copyWith(
            isRefreshing: false,
            refreshFailure: () => failure,
          );
        } else {
          state = state.copyWith(
            snapshot: AsyncError<OverviewSnapshot>(failure, StackTrace.current),
            isRefreshing: false,
            refreshFailure: () => null,
          );
          _syncElapsedTimer(null);
        }
    }
  }

  /// Refreshes the dashboard while preserving any existing snapshot.
  Future<void> refresh() => loadOverview(showLoading: !state.snapshot.hasValue);

  /// Approves a simple `human_approval` pause inline.
  Future<bool> approvePause(String pauseId) =>
      _submitPauseDecision(pauseId, approved: true);

  /// Rejects a simple `human_approval` pause inline.
  Future<bool> rejectPause(String pauseId) =>
      _submitPauseDecision(pauseId, approved: false);

  /// Dismisses the inline error banner on a pause card.
  void dismissPauseError(String pauseId) {
    if (!state.pauseErrors.containsKey(pauseId)) return;
    final nextErrors = Map<String, Failure>.from(state.pauseErrors)
      ..remove(pauseId);
    state = state.copyWith(pauseErrors: nextErrors);
  }

  /// Dismisses the top-level background refresh error banner.
  void dismissRefreshFailure() {
    if (state.refreshFailure == null) return;
    state = state.copyWith(refreshFailure: () => null);
  }

  Future<bool> _submitPauseDecision(
    String pauseId, {
    required bool approved,
  }) async {
    if (state.submittingPauses.containsKey(pauseId)) return false;

    final nextSubmitting =
        Map<String, OverviewPauseAction>.from(state.submittingPauses)
          ..[pauseId] = approved
              ? OverviewPauseAction.approve
              : OverviewPauseAction.reject;
    final nextErrors = Map<String, Failure>.from(state.pauseErrors)
      ..remove(pauseId);
    state = state.copyWith(
      submittingPauses: nextSubmitting,
      pauseErrors: nextErrors,
    );

    final result = await ref.read(answerPauseUseCaseProvider)(
      pauseId,
      AnswerPauseRequest(decision: approved ? 'approved' : 'rejected'),
    );
    if (!ref.mounted) return false;

    final clearedSubmitting = Map<String, OverviewPauseAction>.from(
      state.submittingPauses,
    )..remove(pauseId);

    switch (result) {
      case Success<Pause>():
        final currentSnapshot = state.snapshot.asData?.value;
        final updatedSnapshot = currentSnapshot == null
            ? null
            : _removePauseFromSnapshot(currentSnapshot, pauseId);
        state = state.copyWith(
          snapshot: updatedSnapshot != null
              ? AsyncData<OverviewSnapshot>(updatedSnapshot)
              : state.snapshot,
          submittingPauses: clearedSubmitting,
          hasPendingPausesChanged: updatedSnapshot != null
              ? _trackPendingPausesChanged(updatedSnapshot)
              : state.hasPendingPausesChanged,
        );
        if (updatedSnapshot != null) {
          _syncElapsedTimer(updatedSnapshot);
        }
        unawaited(loadOverview(showLoading: false));
        return true;
      case FailureResult<Pause>(:final failure):
        final updatedErrors = Map<String, Failure>.from(state.pauseErrors)
          ..[pauseId] = failure;
        state = state.copyWith(
          submittingPauses: clearedSubmitting,
          pauseErrors: updatedErrors,
        );
        return false;
    }
  }

  void _handleOverviewEvent(OverviewEvent event) {
    if (!ref.mounted) return;
    _eventEpoch++;
    switch (event) {
      case OverviewRunEventReceived() || OverviewPauseCreatedEvent():
        _scheduleResync();
      case OverviewPauseResolvedEvent(:final pause):
        final currentSnapshot = state.snapshot.asData?.value;
        if (currentSnapshot != null &&
            currentSnapshot.pendingPauses.any((p) => p.pauseId == pause.id)) {
          final updated = _removePauseFromSnapshot(currentSnapshot, pause.id);
          final nextErrors = Map<String, Failure>.from(state.pauseErrors)
            ..remove(pause.id);
          state = state.copyWith(
            snapshot: AsyncData<OverviewSnapshot>(updated),
            pauseErrors: nextErrors,
            hasPendingPausesChanged: _trackPendingPausesChanged(updated),
          );
          _syncElapsedTimer(updated);
        }
        _scheduleResync();
      case OverviewSyncRequestedEvent():
        _resyncTimer?.cancel();
        _resyncTimer = null;
        unawaited(loadOverview(showLoading: false));
    }
  }

  void _scheduleResync() {
    _resyncTimer?.cancel();
    _resyncTimer = _clock.createOneShotTimer(_clock.resyncDebounce, () {
      _resyncTimer = null;
      if (!ref.mounted) return;
      unawaited(loadOverview(showLoading: false));
    });
  }

  bool _trackPendingPausesChanged(OverviewSnapshot snapshot) {
    final count = snapshot.metrics.pendingPausesCount;
    final initial = _initialPendingPausesCount;
    if (initial == null) {
      _initialPendingPausesCount = count;
      return false;
    }
    return state.hasPendingPausesChanged || count != initial;
  }

  void _syncElapsedTimer(OverviewSnapshot? snapshot) {
    final hasActive =
        snapshot != null &&
        (snapshot.activeRuns.isNotEmpty || snapshot.activeNodes.isNotEmpty);
    ref.read(overviewNowProvider.notifier).setActive(hasActive: hasActive);
  }

  OverviewSnapshot _removePauseFromSnapshot(
    OverviewSnapshot snapshot,
    String pauseId,
  ) {
    final nextPauses = snapshot.pendingPauses
        .where((p) => p.pauseId != pauseId)
        .toList();
    return snapshot.copyWith(
      pendingPauses: nextPauses,
      metrics: snapshot.metrics.copyWith(pendingPausesCount: nextPauses.length),
    );
  }
}
