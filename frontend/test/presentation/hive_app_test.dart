import 'dart:async';

import 'package:agentic_hive_frontend/app.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/lifecycle/backend_launcher.dart';
import 'package:agentic_hive_frontend/core/lifecycle/tray_service.dart';
import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:agentic_hive_frontend/core/lifecycle/window_title_provider.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/agents/pages/agents_page.dart';
import 'package:agentic_hive_frontend/presentation/connecting/pages/connecting_page.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/pages/harnesses_page.dart';
import 'package:agentic_hive_frontend/presentation/overview/pages/overview_page.dart';
import 'package:agentic_hive_frontend/presentation/pauses/pages/pauses_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_frontend/presentation/settings/pages/settings_page.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:agentic_hive_frontend/routes/app_router_provider.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeWebSocketSession implements BackendWebSocketSession {
  final StreamController<WsEnvelope> _messages =
      StreamController<WsEnvelope>.broadcast();
  final Completer<void> _done = Completer<void>();

  @override
  ServerHelloPayload get serverHello => const ServerHelloPayload(
    serverVersion: '0.1.0',
    protocolVersion: wsProtocolVersion,
  );

  @override
  Stream<WsEnvelope> get messages => _messages.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => _done.isCompleted;

  @override
  Future<Result<void>> send(WsEnvelope envelope) async => const Success(null);

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!_messages.isClosed) unawaited(_messages.close());
    if (!_done.isCompleted) _done.complete();
  }
}

final class _FakeBackendClient implements BackendClient {
  new({required this.statusResult});

  Result<StatusResponse> statusResult;
  int statusCheckCount = 0;

  @override
  Future<Result<StatusResponse>> checkStatus() async {
    statusCheckCount++;
    return statusResult;
  }

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      Success(_FakeWebSocketSession());

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const Success(ShutdownResponse());

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async {
    if (path == '/api/v1/agents') {
      return const Success(<String, Object?>{'agents': <Object?>[]});
    }
    return const Success(<String, Object?>{'harnesses': <Object?>[]});
  }

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) async => const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<void>> delete(String path) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async => const Success(<String, Object?>{});

  @override
  Future<void> close() async {}
}

final class _FakeBackendLauncher implements BackendLauncher {
  @override
  Result<BackendLaunchTarget> resolveLaunchTarget() =>
      const Success(BackendLaunchTarget(executable: '/fake/backend'));

  @override
  Future<Result<void>> launch() async => const Success(null);
}

final class _FakeWindowLifecycleService implements WindowLifecycleService {
  new({this.hasCustomTitleBar = true, bool initialMaximized = false})
    : _isMaximized = ValueNotifier<bool>(initialMaximized);

  @override
  final bool hasCustomTitleBar;

  final ValueNotifier<bool> _isMaximized;
  int minimizeCount = 0;
  int toggleMaximizeCount = 0;
  int hideToTrayCount = 0;
  int exitApplicationCount = 0;
  int startDraggingCount = 0;
  Offset? lastSystemMenuPosition;

  @override
  ValueListenable<bool> get isMaximized => _isMaximized;

  bool get maximized => _isMaximized.value;

  set maximized(bool value) {
    _isMaximized.value = value;
  }

  @override
  Future<void> initialize({
    required VoidCallback onCloseRequested,
    VoidCallback? onQuitRequested,
  }) async {}

  @override
  Future<void> minimize() async {
    minimizeCount++;
  }

  @override
  Future<void> toggleMaximize() async {
    toggleMaximizeCount++;
    _isMaximized.value = !_isMaximized.value;
  }

  @override
  Future<void> startDragging() async {
    startDraggingCount++;
  }

  @override
  Future<void> showSystemMenu(Offset globalPosition) async {
    lastSystemMenuPosition = globalPosition;
  }

  @override
  Future<void> hideToTray() async {
    hideToTrayCount++;
  }

  @override
  Future<void> showAndFocus() async {}

  @override
  Future<void> exitApplication() async {
    exitApplicationCount++;
  }

  @override
  Future<void> dispose() async {
    _isMaximized.dispose();
  }
}

final class _FakeThemePreferenceStore implements ThemePreferenceStore {
  new({this.initial = AppThemePreference.dark});

  AppThemePreference initial;

  @override
  Future<AppThemePreference> load() async => initial;

  @override
  Future<void> save(AppThemePreference preference) async {
    initial = preference;
  }
}

final class _FakeTrayService implements TrayService {
  @override
  Future<void> initialize({
    required VoidCallback onTrayClick,
    required void Function(TrayAction action) onAction,
  }) async {}

  @override
  Future<void> updateMenu({
    required TrayMenuLabels labels,
    required bool canStopBackend,
  }) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  const desktopSize = Size(1440, 900);
  const okStatus = Success<StatusResponse>(
    StatusResponse(
      status: BackendStatus.ok,
      version: '0.1.0',
      uptimeSeconds: 10,
      dataDir: '/tmp/hive',
      database: DatabaseStatus(ok: true, schemaVersion: 1),
    ),
  );
  const downStatus = FailureResult<StatusResponse>(
    NetworkFailure('Backend unreachable', code: BackendFailureCode.notRunning),
  );

  void configureDesktopWindow(WidgetTester tester) {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  AppLocalizations l10nFrom(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold).first);
    return AppLocalizations.of(context)!;
  }

  group('HiveApp', () {
    testWidgets(
      'side rail navigation switches pages and expands/collapses labels',
      (tester) async {
        configureDesktopWindow(tester);
        final fakeClient = _FakeBackendClient(statusResult: okStatus);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backendClientProvider.overrideWithValue(fakeClient),
              backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
              windowLifecycleServiceProvider.overrideWithValue(
                _FakeWindowLifecycleService(),
              ),
              trayServiceProvider.overrideWithValue(_FakeTrayService()),
              themePreferenceStoreProvider.overrideWithValue(
                _FakeThemePreferenceStore(),
              ),
            ],
            child: const HiveApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HiveSideRail), findsOneWidget);
        expect(find.byType(OverviewPage), findsOneWidget);
        expect(find.byType(HivePageHeader), findsOneWidget);
        expect(find.byType(HiveEmptyState), findsOneWidget);

        final l10n = l10nFrom(tester);

        // Expand rail to verify labels appear, then collapse again.
        await tester.tap(find.bySemanticsLabel(l10n.railExpandTooltip));
        await tester.pumpAndSettle();
        expect(find.text(l10n.navWorkflows), findsOneWidget);

        await tester.tap(find.bySemanticsLabel(l10n.railCollapseTooltip));
        await tester.pumpAndSettle();

        final destinations = <(String, Type)>[
          (l10n.navWorkflows, WorkflowsPage),
          (l10n.navRuns, RunsPage),
          (l10n.navPauses, PausesPage),
          (l10n.navAgents, AgentsPage),
          (l10n.navHarnesses, HarnessesPage),
          (l10n.navSettings, SettingsPage),
          (l10n.navOverview, OverviewPage),
        ];

        for (final (label, pageType) in destinations) {
          await tester.tap(find.bySemanticsLabel(label));
          await tester.pumpAndSettle();

          expect(find.byType(pageType), findsOneWidget);
          expect(find.byType(HivePageHeader), findsOneWidget);
          expect(find.byType(HiveEmptyState), findsAtLeastNWidgets(1));
          expect(
            find.descendant(
              of: find.byType(HivePageHeader),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'starts on /connecting when disconnected and retry invokes reconnect',
      (tester) async {
        configureDesktopWindow(tester);
        final fakeClient = _FakeBackendClient(statusResult: downStatus);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backendClientProvider.overrideWithValue(fakeClient),
              backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
              windowLifecycleServiceProvider.overrideWithValue(
                _FakeWindowLifecycleService(),
              ),
              trayServiceProvider.overrideWithValue(_FakeTrayService()),
              themePreferenceStoreProvider.overrideWithValue(
                _FakeThemePreferenceStore(),
              ),
            ],
            child: const HiveApp(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(ConnectingPage), findsOneWidget);
        expect(find.byType(HiveSideRail), findsNothing);
        final initialChecks = fakeClient.statusCheckCount;

        await tester.tap(find.byType(HiveButton));
        await tester.pump();
        await tester.pump();

        expect(fakeClient.statusCheckCount, greaterThan(initialChecks));
        expect(find.byType(ConnectingPage), findsOneWidget);
      },
    );

    testWidgets(
      'disconnecting redirects to /connecting and reconnecting restores route',
      (tester) async {
        configureDesktopWindow(tester);
        final fakeClient = _FakeBackendClient(statusResult: okStatus);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backendClientProvider.overrideWithValue(fakeClient),
              backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
              windowLifecycleServiceProvider.overrideWithValue(
                _FakeWindowLifecycleService(),
              ),
              trayServiceProvider.overrideWithValue(_FakeTrayService()),
              themePreferenceStoreProvider.overrideWithValue(
                _FakeThemePreferenceStore(),
              ),
            ],
            child: const HiveApp(),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = l10nFrom(tester);

        // Navigate to a non-default route (/workflows).
        await tester.tap(find.bySemanticsLabel(l10n.navWorkflows));
        await tester.pumpAndSettle();
        expect(find.byType(WorkflowsPage), findsOneWidget);

        // Transition to disconnected -> redirects to /connecting.
        fakeClient.statusResult = downStatus;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HiveApp)),
        );
        await container.read(backendConnectionProvider.notifier).reconnect();
        await tester.pumpAndSettle();

        expect(find.byType(ConnectingPage), findsOneWidget);
        expect(find.byType(HiveSideRail), findsNothing);

        // Transition back to connected via retry -> restores /workflows.
        fakeClient.statusResult = okStatus;
        await tester.tap(find.byType(HiveButton));
        await tester.pumpAndSettle();

        expect(find.byType(WorkflowsPage), findsOneWidget);
        expect(find.byType(HiveSideRail), findsOneWidget);
      },
    );

    testWidgets(
      'applies persisted local theme on startup including on /connecting',
      (tester) async {
        configureDesktopWindow(tester);
        final fakeClient = _FakeBackendClient(statusResult: downStatus);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backendClientProvider.overrideWithValue(fakeClient),
              backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
              windowLifecycleServiceProvider.overrideWithValue(
                _FakeWindowLifecycleService(),
              ),
              trayServiceProvider.overrideWithValue(_FakeTrayService()),
              themePreferenceStoreProvider.overrideWithValue(
                _FakeThemePreferenceStore(initial: AppThemePreference.light),
              ),
            ],
            child: const HiveApp(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(ConnectingPage), findsOneWidget);
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.light);
      },
    );

    testWidgets(
      'sets runtime window title from localized appTitle on startup',
      (tester) async {
        configureDesktopWindow(tester);
        final fakeClient = _FakeBackendClient(statusResult: okStatus);
        final recordedTitles = <String>[];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backendClientProvider.overrideWithValue(fakeClient),
              backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
              windowLifecycleServiceProvider.overrideWithValue(
                _FakeWindowLifecycleService(),
              ),
              trayServiceProvider.overrideWithValue(_FakeTrayService()),
              themePreferenceStoreProvider.overrideWithValue(
                _FakeThemePreferenceStore(),
              ),
              windowTitleSetterProvider.overrideWithValue(recordedTitles.add),
            ],
            child: const HiveApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(recordedTitles, <String>['Agentic Hive']);
      },
    );

    testWidgets(
      'mounts custom title bar on shell route, wires actions, and tracks '
      'external maximize changes',
      (tester) async {
        configureDesktopWindow(tester);
        final fakeClient = _FakeBackendClient(statusResult: okStatus);
        final windowService = _FakeWindowLifecycleService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backendClientProvider.overrideWithValue(fakeClient),
              backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
              windowLifecycleServiceProvider.overrideWithValue(windowService),
              trayServiceProvider.overrideWithValue(_FakeTrayService()),
              themePreferenceStoreProvider.overrideWithValue(
                _FakeThemePreferenceStore(),
              ),
            ],
            child: const HiveApp(),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = l10nFrom(tester);
        expect(find.byType(HiveTitleBar), findsOneWidget);

        Finder captionButtons() => find.descendant(
          of: find.byType(HiveTitleBar),
          matching: find.byType(HiveIconButton),
        );
        expect(captionButtons(), findsNWidgets(3));
        expect(
          tester.widget<HiveIconButton>(captionButtons().at(0)).semanticLabel,
          l10n.windowMinimize,
        );
        expect(
          tester.widget<HiveIconButton>(captionButtons().at(1)).semanticLabel,
          l10n.windowMaximize,
        );
        final initialMaximizeIcon = tester
            .widget<HiveIconButton>(captionButtons().at(1))
            .icon;
        expect(
          tester.widget<HiveIconButton>(captionButtons().at(2)).semanticLabel,
          l10n.windowCloseToTray,
        );

        await tester.tap(captionButtons().at(0));
        expect(windowService.minimizeCount, 1);

        await tester.tap(captionButtons().at(1));
        await tester.pump();
        expect(windowService.toggleMaximizeCount, 1);
        expect(
          tester.widget<HiveIconButton>(captionButtons().at(1)).semanticLabel,
          l10n.windowRestore,
        );
        expect(
          tester.widget<HiveIconButton>(captionButtons().at(1)).icon,
          isNot(equals(initialMaximizeIcon)),
        );

        windowService.maximized = false;
        await tester.pump();
        expect(
          tester.widget<HiveIconButton>(captionButtons().at(1)).semanticLabel,
          l10n.windowMaximize,
        );
        expect(
          tester.widget<HiveIconButton>(captionButtons().at(1)).icon,
          equals(initialMaximizeIcon),
        );

        await tester.tap(captionButtons().at(2));
        expect(windowService.hideToTrayCount, 1);
        expect(windowService.exitApplicationCount, 0);
      },
    );

    testWidgets('mounts custom title bar on /connecting and error route', (
      tester,
    ) async {
      configureDesktopWindow(tester);
      final fakeClient = _FakeBackendClient(statusResult: downStatus);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendClientProvider.overrideWithValue(fakeClient),
            backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
            windowLifecycleServiceProvider.overrideWithValue(
              _FakeWindowLifecycleService(),
            ),
            trayServiceProvider.overrideWithValue(_FakeTrayService()),
            themePreferenceStoreProvider.overrideWithValue(
              _FakeThemePreferenceStore(),
            ),
          ],
          child: const HiveApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ConnectingPage), findsOneWidget);
      expect(find.byType(HiveTitleBar), findsOneWidget);

      // Navigate to an unknown route when connected -> RouteErrorPage still
      // has the custom title bar.
      fakeClient.statusResult = okStatus;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HiveApp)),
      );
      await container.read(backendConnectionProvider.notifier).reconnect();
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(HiveTitleBar), findsOneWidget);
    });

    testWidgets('omits custom title bar when hasCustomTitleBar is false', (
      tester,
    ) async {
      configureDesktopWindow(tester);
      final fakeClient = _FakeBackendClient(statusResult: okStatus);
      final windowService = _FakeWindowLifecycleService(
        hasCustomTitleBar: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendClientProvider.overrideWithValue(fakeClient),
            backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
            windowLifecycleServiceProvider.overrideWithValue(windowService),
            trayServiceProvider.overrideWithValue(_FakeTrayService()),
            themePreferenceStoreProvider.overrideWithValue(
              _FakeThemePreferenceStore(),
            ),
          ],
          child: const HiveApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HiveTitleBar), findsNothing);
    });
  });
}
