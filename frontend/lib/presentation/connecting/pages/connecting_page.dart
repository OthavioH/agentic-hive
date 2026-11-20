import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Full-screen connecting and retry view shown when the backend is not ready.
class ConnectingPage extends ConsumerWidget {
  /// Creates a [ConnectingPage].
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(backendConnectionProvider);
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final isConnecting = connection == BackendConnectionState.connecting;
    final isDisconnected = connection == BackendConnectionState.disconnected;

    final indicatorState = switch (connection) {
      BackendConnectionState.connected => HiveConnectionState.connected,
      BackendConnectionState.connecting => HiveConnectionState.connecting,
      BackendConnectionState.disconnected => HiveConnectionState.disconnected,
    };

    final statusLabel = switch (connection) {
      BackendConnectionState.connected => l10n.connectingStatusConnecting,
      BackendConnectionState.connecting => l10n.connectingStatusConnecting,
      BackendConnectionState.disconnected => l10n.connectingStatusDisconnected,
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                HiveHexMark(semanticLabel: l10n.appTitle),
                SizedBox(height: spacing.space3),
                HiveConnectionIndicator(
                  state: indicatorState,
                  label: statusLabel,
                ),
                SizedBox(height: spacing.space2),
                HiveEmptyState(
                  icon: isDisconnected
                      ? HiveIcons.disconnected
                      : HiveIcons.connected,
                  title: l10n.connectingTitle,
                  message: l10n.connectingSubtitle,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
