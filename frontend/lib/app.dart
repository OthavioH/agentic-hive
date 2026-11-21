import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/lifecycle/app_lifecycle_controller.dart';
import 'package:agentic_hive_frontend/core/lifecycle/tray_service.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_controller.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/routes/app_router_provider.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Root widget of the Agentic Hive desktop application.
class HiveApp extends ConsumerWidget {
  /// Creates the root [HiveApp].
  const new({super.key});

  static final NodeVisualRegistry _nodeVisualRegistry =
      createNodeVisualRegistry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themePreference = ref.watch(themePreferenceControllerProvider);
    ref.watch(appLifecycleControllerProvider);

    return NodeVisualScope(
      registry: _nodeVisualRegistry,
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        themeMode: themePreference.toThemeMode(),
        theme: HiveTheme.light(),
        darkTheme: HiveTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => _LifecycleBridge(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _LifecycleBridge extends ConsumerStatefulWidget {
  const new({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<_LifecycleBridge> createState() => _LifecycleBridgeState();
}

class _LifecycleBridgeState extends ConsumerState<_LifecycleBridge> {
  bool _dialogOpen = false;
  TrayMenuLabels? _lastPublishedLabels;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _publishTrayLabels(ref.read(backendConnectionProvider));
  }

  void _publishTrayLabels(BackendConnectionState connection) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final statusHeader = switch (connection) {
      BackendConnected() => l10n.trayStatusConnected,
      BackendConnecting() => l10n.trayStatusStarting,
      BackendDisconnected() => l10n.trayStatusDisconnected,
    };

    final labels = TrayMenuLabels(
      tooltip: l10n.trayTooltip,
      statusHeader: statusHeader,
      openApp: l10n.trayActionOpen,
      quit: l10n.trayActionQuit,
      stopBackendAndQuit: l10n.trayActionStopBackendAndQuit,
    );

    if (labels == _lastPublishedLabels) return;
    _lastPublishedLabels = labels;
    unawaited(
      Future.microtask(() async {
        if (!mounted) return;
        await ref
            .read(appLifecycleControllerProvider.notifier)
            .updateTrayLabels(labels);
      }),
    );
  }

  Future<void> _showStopConfirmationDialog(int activeRuns) async {
    if (_dialogOpen || !mounted) return;
    final navigatorContext =
        widget.router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return;

    final l10n = AppLocalizations.of(navigatorContext)!;
    _dialogOpen = true;
    final confirmed = await showHiveDialog<bool>(
      context: navigatorContext,
      barrierLabel: l10n.dialogDismissLabel,
      builder: (dialogContext) => HiveDialog(
        icon: HiveIcons.alert,
        title: l10n.stopBackendDialogTitle,
        message: l10n.stopBackendDialogMessage(activeRuns),
        actions: <Widget>[
          HiveButton(
            label: l10n.stopBackendDialogCancel,
            variant: HiveButtonVariant.secondary,
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          HiveButton(
            label: l10n.stopBackendDialogConfirm,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;

    final controller = ref.read(appLifecycleControllerProvider.notifier);
    if (confirmed ?? false) {
      await controller.confirmStopBackendAndQuit();
    } else {
      controller.cancelStopBackendAndQuit();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<BackendConnectionState>(
        backendConnectionProvider,
        (_, next) => _publishTrayLabels(next),
      )
      ..listen<AppLifecycleState>(appLifecycleControllerProvider, (prev, next) {
        if (next.pendingStopConfirmation &&
            !(prev?.pendingStopConfirmation ?? false)) {
          unawaited(
            _showStopConfirmationDialog(next.activeRunsForConfirmation),
          );
        }
      });

    return widget.child;
  }
}
