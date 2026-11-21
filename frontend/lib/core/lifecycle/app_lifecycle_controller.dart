import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/lifecycle/backend_launcher.dart';
import 'package:agentic_hive_frontend/core/lifecycle/tray_service.dart';
import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_lifecycle_controller.g.dart';

/// Snapshot of desktop lifecycle, backend auto-launch, and quit confirmation
/// state.
@immutable
final class AppLifecycleState {
  /// Creates an [AppLifecycleState].
  const new({
    this.isLaunchingBackend = false,
    this.hasAttemptedAutoLaunch = false,
    this.launchFailure,
    this.pendingStopConfirmation = false,
    this.activeRunsForConfirmation = 0,
    this.isShuttingDown = false,
  });

  /// Whether the app is currently spawning the local backend process.
  final bool isLaunchingBackend;

  /// Whether the one-shot startup launch check has already run.
  final bool hasAttemptedAutoLaunch;

  /// Non-null when launching the local backend process failed.
  final Failure? launchFailure;

  /// Whether the user requested **Stop Backend & Quit** while runs are active
  /// and must confirm in the app dialog.
  final bool pendingStopConfirmation;

  /// Number of active runs reported when confirmation was requested.
  final int activeRunsForConfirmation;

  /// Whether an exit sequence is currently in progress.
  final bool isShuttingDown;

  /// Returns a copy with updated fields.
  AppLifecycleState copyWith({
    bool? isLaunchingBackend,
    bool? hasAttemptedAutoLaunch,
    Failure? launchFailure,
    bool clearLaunchFailure = false,
    bool? pendingStopConfirmation,
    int? activeRunsForConfirmation,
    bool? isShuttingDown,
  }) => AppLifecycleState(
    isLaunchingBackend: isLaunchingBackend ?? this.isLaunchingBackend,
    hasAttemptedAutoLaunch:
        hasAttemptedAutoLaunch ?? this.hasAttemptedAutoLaunch,
    launchFailure: clearLaunchFailure
        ? null
        : (launchFailure ?? this.launchFailure),
    pendingStopConfirmation:
        pendingStopConfirmation ?? this.pendingStopConfirmation,
    activeRunsForConfirmation:
        activeRunsForConfirmation ?? this.activeRunsForConfirmation,
    isShuttingDown: isShuttingDown ?? this.isShuttingDown,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLifecycleState &&
          other.isLaunchingBackend == isLaunchingBackend &&
          other.hasAttemptedAutoLaunch == hasAttemptedAutoLaunch &&
          other.launchFailure == launchFailure &&
          other.pendingStopConfirmation == pendingStopConfirmation &&
          other.activeRunsForConfirmation == activeRunsForConfirmation &&
          other.isShuttingDown == isShuttingDown;

  @override
  int get hashCode => Object.hash(
    isLaunchingBackend,
    hasAttemptedAutoLaunch,
    launchFailure,
    pendingStopConfirmation,
    activeRunsForConfirmation,
    isShuttingDown,
  );
}

/// Coordinates backend auto-launch on startup, window close-to-tray behavior,
/// system tray menu actions, and graceful backend shutdown (Spec #13).
@Riverpod(keepAlive: true)
class AppLifecycleController extends _$AppLifecycleController {
  TrayMenuLabels? _lastLabels;
  bool? _lastCanStopBackend;
  bool _servicesInitialized = false;

  @override
  AppLifecycleState build() {
    ref.listen<BackendConnectionState>(backendConnectionProvider, (_, next) {
      if (next is BackendConnected) {
        state = state.copyWith(
          hasAttemptedAutoLaunch: true,
          clearLaunchFailure: true,
        );
      } else if (next is BackendDisconnected &&
          !state.hasAttemptedAutoLaunch &&
          (next.reason == ConnectionFailureReason.notRunning ||
              next.reason == ConnectionFailureReason.connectionRefused)) {
        unawaited(_launchBackendOnce());
      }
      unawaited(_syncTrayMenuForConnection(next));
    });

    unawaited(Future.microtask(_initialize));
    return const AppLifecycleState();
  }

  Future<void> _initialize() async {
    if (!ref.mounted) return;
    if (!_servicesInitialized) {
      _servicesInitialized = true;
      await ref
          .read(windowLifecycleServiceProvider)
          .initialize(
            onCloseRequested: () => unawaited(handleWindowCloseRequested()),
            onQuitRequested: () => unawaited(handleQuitRequested()),
          );
      if (!ref.mounted) return;

      await ref
          .read(trayServiceProvider)
          .initialize(
            onTrayClick: () => unawaited(handleOpenWindow()),
            onAction: (action) => unawaited(handleTrayAction(action)),
          );
      if (!ref.mounted) return;
    }

    final connection = ref.read(backendConnectionProvider);
    if (connection is BackendConnected) {
      state = state.copyWith(
        hasAttemptedAutoLaunch: true,
        clearLaunchFailure: true,
      );
    } else if (connection is BackendDisconnected &&
        !state.hasAttemptedAutoLaunch &&
        (connection.reason == ConnectionFailureReason.notRunning ||
            connection.reason == ConnectionFailureReason.connectionRefused)) {
      await _launchBackendOnce();
    }
  }

  Future<void> _launchBackendOnce() async {
    if (!ref.mounted || state.hasAttemptedAutoLaunch) return;

    state = state.copyWith(
      hasAttemptedAutoLaunch: true,
      isLaunchingBackend: true,
      clearLaunchFailure: true,
    );

    final launchResult = await ref.read(backendLauncherProvider).launch();
    if (!ref.mounted) return;

    switch (launchResult) {
      case Success<void>():
        state = state.copyWith(
          isLaunchingBackend: false,
          clearLaunchFailure: true,
        );
        unawaited(ref.read(backendConnectionProvider.notifier).reconnect());
      case FailureResult<void>(:final failure):
        state = state.copyWith(
          isLaunchingBackend: false,
          launchFailure: failure,
        );
    }
  }

  /// Retries launching the backend if no live socket answers, then triggers
  /// `BackendConnection.reconnect()`.
  Future<void> retryLaunchAndReconnect() async {
    if (!ref.mounted) return;

    final statusResult = await ref.read(backendClientProvider).checkStatus();
    if (!ref.mounted) return;

    if (statusResult is FailureResult<StatusResponse>) {
      state = state.copyWith(
        isLaunchingBackend: true,
        clearLaunchFailure: true,
      );
      final launchResult = await ref.read(backendLauncherProvider).launch();
      if (!ref.mounted) return;
      switch (launchResult) {
        case Success<void>():
          state = state.copyWith(
            isLaunchingBackend: false,
            clearLaunchFailure: true,
          );
        case FailureResult<void>(:final failure):
          state = state.copyWith(
            isLaunchingBackend: false,
            launchFailure: failure,
          );
      }
    } else {
      state = state.copyWith(clearLaunchFailure: true);
    }

    await ref.read(backendConnectionProvider.notifier).reconnect();
  }

  /// Updates the tray menu with localized labels from the active UI context.
  Future<void> updateTrayLabels(TrayMenuLabels labels) async {
    _lastLabels = labels;
    final connection = ref.read(backendConnectionProvider);
    final canStop = connection.isConnected;
    _lastCanStopBackend = canStop;
    await ref
        .read(trayServiceProvider)
        .updateMenu(labels: labels, canStopBackend: canStop);
  }

  Future<void> _syncTrayMenuForConnection(
    BackendConnectionState connection,
  ) async {
    final labels = _lastLabels;
    if (labels == null) return;
    final canStop = connection.isConnected;
    if (_lastCanStopBackend == canStop) return;
    _lastCanStopBackend = canStop;
    await ref
        .read(trayServiceProvider)
        .updateMenu(labels: labels, canStopBackend: canStop);
  }

  /// Handles window close interception by hiding the window to the tray.
  Future<void> handleWindowCloseRequested() async {
    if (!ref.mounted) return;
    await ref.read(windowLifecycleServiceProvider).hideToTray();
  }

  /// Restores and focuses the main window.
  Future<void> handleOpenWindow() async {
    if (!ref.mounted) return;
    await ref.read(windowLifecycleServiceProvider).showAndFocus();
  }

  /// Dispatches a tray menu [action].
  Future<void> handleTrayAction(TrayAction action) => switch (action) {
    TrayAction.openWindow => handleOpenWindow(),
    TrayAction.quit => handleQuitRequested(),
    TrayAction.stopBackendAndQuit => handleStopBackendAndQuitRequested(),
  };

  /// Handles **Quit** (from tray or macOS `Cmd+Q`):
  /// - If backend is reachable and `activeRuns == 0`: shuts down backend
  ///   (`force: false`) and exits.
  /// - If `activeRuns > 0` or backend is unreachable: exits UI only, leaving
  ///   any running backend alive.
  Future<void> handleQuitRequested() async {
    if (!ref.mounted || state.isShuttingDown) return;
    state = state.copyWith(isShuttingDown: true);

    final client = ref.read(backendClientProvider);
    final statusResult = await client.checkStatus();
    if (!ref.mounted) return;

    if (statusResult case Success<StatusResponse>(:final value)) {
      if (value.activeRuns == 0) {
        await client.shutdown(force: false);
        if (!ref.mounted) return;
      }
    }

    await ref.read(windowLifecycleServiceProvider).exitApplication();
  }

  /// Handles **Stop Backend & Quit** from the tray:
  /// - If `activeRuns == 0`: shuts down backend and exits immediately.
  /// - If `activeRuns > 0`: restores/focuses window and requests in-app
  ///   confirmation before force-shutting down.
  Future<void> handleStopBackendAndQuitRequested() async {
    if (!ref.mounted || state.isShuttingDown) return;

    final client = ref.read(backendClientProvider);
    final statusResult = await client.checkStatus();
    if (!ref.mounted) return;

    switch (statusResult) {
      case Success<StatusResponse>(:final value):
        if (value.activeRuns == 0) {
          state = state.copyWith(isShuttingDown: true);
          final shutdownResult = await client.shutdown(force: false);
          if (!ref.mounted) return;
          if (shutdownResult
              case FailureResult<ShutdownResponse>(:final failure)
              when failure is BackendFailure && failure.statusCode == 409) {
            state = state.copyWith(
              isShuttingDown: false,
              pendingStopConfirmation: true,
              activeRunsForConfirmation: 1,
            );
            await ref.read(windowLifecycleServiceProvider).showAndFocus();
            return;
          }
          await ref.read(windowLifecycleServiceProvider).exitApplication();
        } else {
          await ref.read(windowLifecycleServiceProvider).showAndFocus();
          if (!ref.mounted) return;
          state = state.copyWith(
            pendingStopConfirmation: true,
            activeRunsForConfirmation: value.activeRuns,
          );
        }
      case FailureResult<StatusResponse>():
        state = state.copyWith(isShuttingDown: true);
        await ref.read(windowLifecycleServiceProvider).exitApplication();
    }
  }

  /// Confirms force-stopping the backend with active runs and exits.
  Future<void> confirmStopBackendAndQuit() async {
    if (!ref.mounted || state.isShuttingDown) return;
    state = state.copyWith(
      pendingStopConfirmation: false,
      isShuttingDown: true,
    );
    await ref.read(backendClientProvider).shutdown(force: true);
    if (!ref.mounted) return;
    await ref.read(windowLifecycleServiceProvider).exitApplication();
  }

  /// Cancels the pending **Stop Backend & Quit** confirmation dialog.
  void cancelStopBackendAndQuit() {
    if (!ref.mounted) return;
    state = state.copyWith(pendingStopConfirmation: false);
  }
}
