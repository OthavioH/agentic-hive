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
  Result<StatusResponse> statusResult = const FailureResult(
    NetworkFailure('missing', code: BackendFailureCode.notRunning),
  );
  final List<bool> shutdownForceCalls = <bool>[];

  @override
  Future<Result<StatusResponse>> checkStatus() async => statusResult;

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      Success(_FakeWebSocketSession());

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async {
    shutdownForceCalls.add(force);
    return const Success(ShutdownResponse());
  }

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async =>
      const FailureResult(NetworkFailure('unused'));

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
  Result<void> nextResult = const Success(null);
  int launchCount = 0;

  @override
  Result<BackendLaunchTarget> resolveLaunchTarget() =>
      const Success(BackendLaunchTarget(executable: '/fake/backend'));

  @override
  Future<Result<void>> launch() async {
    launchCount++;
    return nextResult;
  }
}

final class _FakeWindowLifecycleService implements WindowLifecycleService {
  int showCount = 0;
  int exitCount = 0;
  final ValueNotifier<bool> _isMaximized = ValueNotifier<bool>(false);

  @override
  bool get hasCustomTitleBar => true;

  @override
  bool get showSystemMenuOnRelease => false;

  @override
  ValueListenable<bool> get isMaximized => _isMaximized;

  @override
  void configureTitleBar() {}

  @override
  Future<Result<void>> setTitle(String title) async =>
      const Success<void>(null);

  @override
  Future<void> initialize({
    required VoidCallback onCloseRequested,
    VoidCallback? onQuitRequested,
  }) async {}

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> startDragging() async {}

  @override
  Future<void> showSystemMenu(Offset globalPosition) async {}

  @override
  Future<void> hideToTray() async {}

  @override
  Future<void> showAndFocus() async {
    showCount++;
  }

  @override
  Future<void> exitApplication() async {
    exitCount++;
  }

  @override
  Future<void> dispose() async {}
}

final class _FakeTrayService implements TrayService {
  void Function(TrayAction action)? onAction;
  TrayMenuLabels? lastLabels;
  bool? lastCanStopBackend;

  @override
  Future<void> initialize({
    required VoidCallback onTrayClick,
    required void Function(TrayAction action) onAction,
  }) async {
    this.onAction = onAction;
  }

  @override
  Future<void> updateMenu({
    required TrayMenuLabels labels,
    required bool canStopBackend,
  }) async {
    lastLabels = labels;
    lastCanStopBackend = canStopBackend;
  }

  @override
  Future<void> dispose() async {}
}

final class _FakeTimer implements Timer {
  new(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;

  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}

void main() {
  const desktopSize = Size(1440, 900);

  void configureDesktopWindow(WidgetTester tester) {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('Lifecycle UI integration', () {
    testWidgets('ConnectingPage displays launch failure when launcher fails', (
      tester,
    ) async {
      configureDesktopWindow(tester);
      final client = _FakeBackendClient();
      final launcher = _FakeBackendLauncher()
        ..nextResult = const FailureResult(
          NotFoundFailure('Backend binary missing'),
        );
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendClientProvider.overrideWithValue(client),
            backendLauncherProvider.overrideWithValue(launcher),
            windowLifecycleServiceProvider.overrideWithValue(windowService),
            trayServiceProvider.overrideWithValue(trayService),
            backendConnectionConfigProvider.overrideWithValue(
              const BackendConnectionConfig(createTimer: _FakeTimer.new),
            ),
          ],
          child: const HiveApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectingPage), findsOneWidget);
      final context = tester.element(find.byType(ConnectingPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.connectingReasonLaunchFailedTitle), findsOneWidget);
      expect(
        find.text(l10n.connectingReasonLaunchFailedMessage),
        findsOneWidget,
      );
      expect(launcher.launchCount, 1);
    });

    testWidgets('Stop Backend & Quit shows HiveDialog when activeRuns > 0 and '
        'calls shutdown(force: true) on confirm', (tester) async {
      configureDesktopWindow(tester);
      final client = _FakeBackendClient()
        ..statusResult = const Success(
          StatusResponse(
            status: BackendStatus.ok,
            version: '0.1.0',
            uptimeSeconds: 10,
            dataDir: '/tmp/hive',
            database: DatabaseStatus(ok: true, schemaVersion: 1),
            activeRuns: 2,
          ),
        );
      final launcher = _FakeBackendLauncher();
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backendClientProvider.overrideWithValue(client),
            backendLauncherProvider.overrideWithValue(launcher),
            windowLifecycleServiceProvider.overrideWithValue(windowService),
            trayServiceProvider.overrideWithValue(trayService),
            backendConnectionConfigProvider.overrideWithValue(
              const BackendConnectionConfig(createTimer: _FakeTimer.new),
            ),
          ],
          child: const HiveApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(trayService.lastCanStopBackend, isTrue);

      trayService.onAction?.call(TrayAction.stopBackendAndQuit);
      await tester.pumpAndSettle();

      expect(find.byType(HiveDialog), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(HiveDialog)),
      )!;
      expect(find.text(l10n.stopBackendDialogTitle), findsOneWidget);

      // Cancel first -> closes dialog without shutting down.
      await tester.tap(find.text(l10n.stopBackendDialogCancel));
      await tester.pumpAndSettle();

      expect(find.byType(HiveDialog), findsNothing);
      expect(client.shutdownForceCalls, isEmpty);
      expect(windowService.exitCount, 0);

      // Trigger again and confirm -> force shutdown & exit.
      trayService.onAction?.call(TrayAction.stopBackendAndQuit);
      await tester.pumpAndSettle();
      expect(find.byType(HiveDialog), findsOneWidget);

      await tester.tap(find.text(l10n.stopBackendDialogConfirm));
      await tester.pumpAndSettle();

      expect(client.shutdownForceCalls, [true]);
      expect(windowService.exitCount, 1);
    });
  });
}
