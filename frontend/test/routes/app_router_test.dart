import 'dart:async';

import 'package:agentic_hive_frontend/app.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/lifecycle/backend_launcher.dart';
import 'package:agentic_hive_frontend/core/lifecycle/tray_service.dart';
import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/connecting/pages/connecting_page.dart';
import 'package:agentic_hive_frontend/presentation/error/pages/route_error_page.dart';
import 'package:agentic_hive_frontend/presentation/overview/pages/overview_page.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:agentic_hive_frontend/routes/app_router_provider.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
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
    drop();
  }

  void drop() {
    if (!_messages.isClosed) unawaited(_messages.close());
    if (!_done.isCompleted) _done.complete();
  }
}

final class _FakeBackendClient implements BackendClient {
  FutureOr<Result<BackendWebSocketSession>> Function()? onConnectWebSocket;

  @override
  Future<Result<StatusResponse>> checkStatus() async => const Success(
    StatusResponse(
      status: BackendStatus.ok,
      version: '0.1.0',
      uptimeSeconds: 10,
      dataDir: '/tmp/hive',
      database: DatabaseStatus(ok: true, schemaVersion: 1),
    ),
  );

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async {
    final handler = onConnectWebSocket;
    if (handler != null) return await handler();
    return Success(_FakeWebSocketSession());
  }

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const Success(ShutdownResponse());

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async =>
      const Success(<String, Object?>{'harnesses': <Object?>[]});

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) async => const FailureResult(NetworkFailure('unused'));

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
  @override
  Future<void> initialize({
    required VoidCallback onCloseRequested,
    VoidCallback? onQuitRequested,
  }) async {}

  @override
  Future<void> hideToTray() async {}

  @override
  Future<void> showAndFocus() async {}

  @override
  Future<void> exitApplication() async {}

  @override
  Future<void> dispose() async {}
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

final class _FakeTimer implements Timer {
  new(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _active = false;
  }

  void fire() {
    if (!_active) return;
    _active = false;
    _tick++;
    callback();
  }
}

void main() {
  testWidgets('unknown route renders localized RouteErrorPage and recovers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendClientProvider.overrideWithValue(_FakeBackendClient()),
          backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
          windowLifecycleServiceProvider.overrideWithValue(
            _FakeWindowLifecycleService(),
          ),
          trayServiceProvider.overrideWithValue(_FakeTrayService()),
        ],
        child: const HiveApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HiveApp)),
    );
    container.read(appRouterProvider).go('/unknown-deep-link');
    await tester.pumpAndSettle();

    expect(find.byType(RouteErrorPage), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RouteErrorPage)),
    )!;
    expect(find.text(l10n.routeErrorTitle), findsOneWidget);

    await tester.tap(find.byType(HiveButton));
    await tester.pumpAndSettle();

    expect(find.byType(OverviewPage), findsOneWidget);
  });

  testWidgets(
    'quick WebSocket recovery within 2s keeps user on current route',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final firstSession = _FakeWebSocketSession();
      final secondSession = _FakeWebSocketSession();
      var calls = 0;
      final fake = _FakeBackendClient()
        ..onConnectWebSocket = () {
          calls++;
          return Success(calls == 1 ? firstSession : secondSession);
        };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendClientProvider.overrideWithValue(fake),
            backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
            windowLifecycleServiceProvider.overrideWithValue(
              _FakeWindowLifecycleService(),
            ),
            trayServiceProvider.overrideWithValue(_FakeTrayService()),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(nextRandomDouble: () => 0.5),
            ),
          ],
          child: const HiveApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HiveApp)),
      );
      container.read(appRouterProvider).go(WorkflowsRoute.path);
      await tester.pumpAndSettle();
      expect(find.byType(WorkflowsPage), findsOneWidget);

      // Drop the session; immediate silent reconnect succeeds.
      firstSession.drop();
      await tester.pumpAndSettle();

      expect(find.byType(WorkflowsPage), findsOneWidget);
      expect(find.byType(ConnectingPage), findsNothing);
    },
  );

  testWidgets(
    'grace period timeout redirects to /connecting and restores remembered route',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final timers = <_FakeTimer>[];
      final firstSession = _FakeWebSocketSession();
      final recoveredSession = _FakeWebSocketSession();
      var shouldFail = false;
      var calls = 0;
      final fake = _FakeBackendClient()
        ..onConnectWebSocket = () {
          calls++;
          if (calls == 1) return Success(firstSession);
          if (shouldFail) {
            return const FailureResult(
              NetworkFailure(
                'refused',
                code: BackendFailureCode.connectionRefused,
              ),
            );
          }
          return Success(recoveredSession);
        };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendClientProvider.overrideWithValue(fake),
            backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
            windowLifecycleServiceProvider.overrideWithValue(
              _FakeWindowLifecycleService(),
            ),
            trayServiceProvider.overrideWithValue(_FakeTrayService()),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(
                nextRandomDouble: () => 0.5,
                createTimer: (duration, callback) {
                  final timer = _FakeTimer(duration, callback);
                  timers.add(timer);
                  return timer;
                },
              ),
            ),
          ],
          child: const HiveApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HiveApp)),
      );
      container.read(appRouterProvider).go(WorkflowsRoute.path);
      await tester.pumpAndSettle();
      expect(find.byType(WorkflowsPage), findsOneWidget);

      // Drop session while backend is down; expire the 2-second grace timer.
      shouldFail = true;
      firstSession.drop();
      await tester.pump();
      expect(timers, isNotEmpty);
      timers.last.fire();
      await tester.pumpAndSettle();

      expect(find.byType(ConnectingPage), findsOneWidget);

      // Recover and verify remembered route (/workflows) is restored.
      shouldFail = false;
      await container.read(backendConnectionProvider.notifier).reconnect();
      await tester.pumpAndSettle();

      expect(find.byType(WorkflowsPage), findsOneWidget);
    },
  );
}
