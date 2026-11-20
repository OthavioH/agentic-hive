import 'dart:async';
import 'dart:math';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Full-screen connecting and retry view shown when the backend is not ready.
class ConnectingPage extends ConsumerStatefulWidget {
  /// Creates a [ConnectingPage].
  const new({super.key});

  @override
  ConsumerState<ConnectingPage> createState() => _ConnectingPageState();
}

class _ConnectingPageState extends ConsumerState<ConnectingPage> {
  static const int _tickSeconds = 1;
  static const Duration _tickInterval = Duration(seconds: _tickSeconds);

  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _syncCountdownTimer(BackendConnectionState connection) {
    final shouldTick = switch (connection) {
      BackendDisconnected(:final nextRetryAt) => nextRetryAt != null,
      _ => false,
    };

    if (shouldTick && _countdownTimer == null) {
      _countdownTimer = Timer.periodic(_tickInterval, (_) {
        if (mounted) setState(() {});
      });
    } else if (!shouldTick && _countdownTimer != null) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(backendConnectionProvider);
    _syncCountdownTimer(connection);

    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final config = ref.watch(backendConnectionConfigProvider);

    final indicatorState = switch (connection) {
      BackendConnected() => HiveConnectionState.connected,
      BackendConnecting() => HiveConnectionState.connecting,
      BackendDisconnected() => HiveConnectionState.disconnected,
    };

    final statusLabel = switch (connection) {
      BackendConnected() ||
      BackendConnecting() => l10n.connectingStatusConnecting,
      BackendDisconnected() => l10n.connectingStatusDisconnected,
    };

    final (title, message, icon) = switch (connection) {
      BackendConnected() || BackendConnecting() => (
        l10n.connectingTitle,
        l10n.connectingSubtitle,
        HiveIcons.connected,
      ),
      BackendDisconnected(:final reason) => _reasonCopy(reason, l10n),
    };

    final isConnecting = connection.isConnecting;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.space4),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: spacing.space8 * 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  HiveHexMark(semanticLabel: l10n.appTitle),
                  SizedBox(height: spacing.space3),
                  HiveConnectionIndicator(
                    state: indicatorState,
                    label: statusLabel,
                  ),
                  SizedBox(height: spacing.space3),
                  HiveCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        HiveEmptyState(
                          icon: icon,
                          title: title,
                          message: message,
                          action: HiveButton(
                            label: l10n.connectingRetryAction,
                            icon: HiveIcons.refresh,
                            loading: isConnecting,
                            onPressed: isConnecting
                                ? null
                                : () => ref
                                      .read(backendConnectionProvider.notifier)
                                      .reconnect(),
                          ),
                        ),
                        if (connection case BackendDisconnected())
                          _RetryStatusRow(
                            state: connection,
                            now: config.now(),
                            l10n: l10n,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, String, HiveIconData) _reasonCopy(
    ConnectionFailureReason reason,
    AppLocalizations l10n,
  ) => switch (reason) {
    ConnectionFailureReason.notRunning => (
      l10n.connectingReasonNotRunningTitle,
      l10n.connectingReasonNotRunningMessage,
      HiveIcons.disconnected,
    ),
    ConnectionFailureReason.connectionRefused => (
      l10n.connectingReasonRefusedTitle,
      l10n.connectingReasonRefusedMessage,
      HiveIcons.disconnected,
    ),
    ConnectionFailureReason.degraded => (
      l10n.connectingReasonDegradedTitle,
      l10n.connectingReasonDegradedMessage,
      HiveIcons.alert,
    ),
    ConnectionFailureReason.protocolMismatch => (
      l10n.connectingReasonProtocolMismatchTitle,
      l10n.connectingReasonProtocolMismatchMessage,
      HiveIcons.alert,
    ),
    ConnectionFailureReason.timeout => (
      l10n.connectingReasonTimeoutTitle,
      l10n.connectingReasonTimeoutMessage,
      HiveIcons.clock,
    ),
    ConnectionFailureReason.unexpected => (
      l10n.connectingReasonUnexpectedTitle,
      l10n.connectingReasonUnexpectedMessage,
      HiveIcons.alert,
    ),
  };
}

class _RetryStatusRow extends StatelessWidget {
  const new({required this.state, required this.now, required this.l10n});

  final BackendDisconnected state;
  final DateTime now;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final retryAt = state.nextRetryAt;
    final remainingSeconds = retryAt == null
        ? null
        : max(0, (retryAt.difference(now).inMilliseconds / 1000).ceil());

    return Padding(
      padding: EdgeInsets.only(top: spacing.space1),
      child: Wrap(
        spacing: spacing.space1,
        runSpacing: spacing.space1,
        alignment: WrapAlignment.center,
        children: <Widget>[
          HiveBadge(label: l10n.connectingAttemptCount(state.attempt)),
          if (remainingSeconds != null)
            HiveBadge(
              label: l10n.connectingNextRetryIn(remainingSeconds),
              icon: HiveIcons.clock,
              tone: HiveBadgeTone.warning,
            )
          else
            HiveBadge(
              label: l10n.connectingAutoRetryHalted,
              icon: HiveIcons.alert,
              tone: HiveBadgeTone.danger,
            ),
        ],
      ),
    );
  }
}
