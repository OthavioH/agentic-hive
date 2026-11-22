import 'dart:async';
import 'dart:ui';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/lifecycle/app_lifecycle_controller.dart';
import 'package:agentic_hive_frontend/core/lifecycle/backend_launcher.dart';
import 'package:agentic_hive_frontend/core/lifecycle/tray_service.dart';
import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    NetworkFailure('not running', code: BackendFailureCode.notRunning),
  );
  final List<bool> shutdownForceCalls = <bool>[];
  Result<ShutdownResponse> shutdownResult = const Success(ShutdownResponse());

  @override
  Future<Result<StatusResponse>> checkStatus() async => statusResult;

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      Success(_FakeWebSocketSession());

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async {
    shutdownForceCalls.add(force);
    return shutdownResult;
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
  int launchCount = 0;
  Result<void> nextResult = const Success(null);

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
  new({this.events, this.onExitApplication});

  final List<String>? events;
  final VoidCallback? onExitApplication;
  VoidCallback? onCloseRequested;
  VoidCallback? onQuitRequested;
  int hideCount = 0;
  int showCount = 0;
  int exitCount = 0;
  bool disposed = false;
  bool exiting = false;
  final ValueNotifier<bool> _isMaximized = ValueNotifier<bool>(false);

  @override
  bool get hasCustomTitleBar => true;

  @override
  ValueListenable<bool> get isMaximized => _isMaximized;

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> startDragging() async {}

  @override
  Future<void> showSystemMenu(Offset globalPosition) async {}

  /// Simulates an OS quit request (`ApplicationQuitRequestedEvent`) that is
  /// cancelled and forwarded to [onQuitRequested] unless [exiting] or
  /// [disposed] is already true.
  ///
  /// Returns `true` if the quit request was allowed to complete (not
  /// intercepted), or `false` if it was cancelled and forwarded to
  /// [onQuitRequested].
  bool simulateOsQuitRequest() {
    if (exiting || disposed) {
      events?.add('osQuitCompleted');
      return true;
    }
    events?.add('osQuitCancelled');
    onQuitRequested?.call();
    return false;
  }

  @override
  Future<void> initialize({
    required VoidCallback onCloseRequested,
    VoidCallback? onQuitRequested,
  }) async {
    this.onCloseRequested = onCloseRequested;
    this.onQuitRequested = onQuitRequested;
  }

  @override
  Future<void> hideToTray() async {
    hideCount++;
  }

  @override
  Future<void> showAndFocus() async {
    showCount++;
  }

  @override
  Future<void> exitApplication() async {
    exiting = true;
    exitCount++;
    events?.add('window.exitApplication');
    onExitApplication?.call();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    events?.add('window.dispose');
  }
}

final class _FakeTrayService implements TrayService {
  new({this.events});

  final List<String>? events;
  VoidCallback? onTrayClick;
  void Function(TrayAction action)? onAction;
  TrayMenuLabels? lastLabels;
  bool? lastCanStopBackend;
  bool disposed = false;

  @override
  Future<void> initialize({
    required VoidCallback onTrayClick,
    required void Function(TrayAction action) onAction,
  }) async {
    this.onTrayClick = onTrayClick;
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
  Future<void> dispose() async {
    disposed = true;
    events?.add('tray.dispose');
  }
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

StatusResponse _status({int activeRuns = 0}) => StatusResponse(
  status: BackendStatus.ok,
  version: '0.1.0',
  uptimeSeconds: 10,
  dataDir: '/tmp/hive',
  database: const DatabaseStatus(ok: true, schemaVersion: 1),
  activeRuns: activeRuns,
);

void main() {
  Future<void> flushMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  ProviderContainer createContainer({
    required _FakeBackendClient client,
    required _FakeBackendLauncher launcher,
    required _FakeWindowLifecycleService windowService,
    required _FakeTrayService trayService,
  }) => ProviderContainer.test(
    overrides: [
      backendClientProvider.overrideWithValue(client),
      backendLauncherProvider.overrideWithValue(launcher),
      windowLifecycleServiceProvider.overrideWithValue(windowService),
      trayServiceProvider.overrideWithValue(trayService),
      backendConnectionConfigProvider.overrideWithValue(
        const BackendConnectionConfig(createTimer: _FakeTimer.new),
      ),
    ],
  );

  group('AppLifecycleController', () {
    test('skips backend launch when live backend already answers', () async {
      final client = _FakeBackendClient()..statusResult = Success(_status());
      final launcher = _FakeBackendLauncher();
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      final container = createContainer(
        client: client,
        launcher: launcher,
        windowService: windowService,
        trayService: trayService,
      )..read(appLifecycleControllerProvider);
      await flushMicrotasks();

      expect(launcher.launchCount, 0);
      expect(
        container.read(appLifecycleControllerProvider).launchFailure,
        isNull,
      );
    });

    test('auto-launches backend once when no live socket answers', () async {
      final client = _FakeBackendClient();
      final launcher = _FakeBackendLauncher();
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      final container = createContainer(
        client: client,
        launcher: launcher,
        windowService: windowService,
        trayService: trayService,
      )..read(appLifecycleControllerProvider);
      await flushMicrotasks();

      expect(launcher.launchCount, 1);
      expect(
        container.read(appLifecycleControllerProvider).launchFailure,
        isNull,
      );
    });

    test(
      'surfaces launch failure clearly without infinite retry loops',
      () async {
        final client = _FakeBackendClient();
        final launcher = _FakeBackendLauncher()
          ..nextResult = const FailureResult(
            NotFoundFailure('Backend binary missing'),
          );
        final windowService = _FakeWindowLifecycleService();
        final trayService = _FakeTrayService();

        final container = createContainer(
          client: client,
          launcher: launcher,
          windowService: windowService,
          trayService: trayService,
        )..read(appLifecycleControllerProvider);
        await flushMicrotasks();

        final state = container.read(appLifecycleControllerProvider);
        expect(launcher.launchCount, 1);
        expect(state.isLaunchingBackend, isFalse);
        expect(state.launchFailure, isA<NotFoundFailure>());

        // Dropping connection later does not re-launch automatically.
        await container.read(backendConnectionProvider.notifier).reconnect();
        await flushMicrotasks();
        expect(launcher.launchCount, 1);
      },
    );

    test('window close hides to tray; tray click / Open restores', () async {
      final client = _FakeBackendClient()..statusResult = Success(_status());
      final launcher = _FakeBackendLauncher();
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      createContainer(
        client: client,
        launcher: launcher,
        windowService: windowService,
        trayService: trayService,
      ).read(appLifecycleControllerProvider);
      await flushMicrotasks();

      windowService.onCloseRequested?.call();
      await flushMicrotasks();
      expect(windowService.hideCount, 1);
      expect(windowService.exitCount, 0);

      trayService.onTrayClick?.call();
      await flushMicrotasks();
      expect(windowService.showCount, 1);

      trayService.onAction?.call(TrayAction.openWindow);
      await flushMicrotasks();
      expect(windowService.showCount, 2);
    });

    test('Quit calls shutdown(force: false) when activeRuns == 0', () async {
      final client = _FakeBackendClient()..statusResult = Success(_status());
      final launcher = _FakeBackendLauncher();
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      createContainer(
        client: client,
        launcher: launcher,
        windowService: windowService,
        trayService: trayService,
      ).read(appLifecycleControllerProvider);
      await flushMicrotasks();

      trayService.onAction?.call(TrayAction.quit);
      await flushMicrotasks();

      expect(client.shutdownForceCalls, [false]);
      expect(windowService.exitCount, 1);
    });

    test('Quit skips shutdown when activeRuns > 0', () async {
      final client = _FakeBackendClient()
        ..statusResult = Success(_status(activeRuns: 2));
      final launcher = _FakeBackendLauncher();
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      createContainer(
        client: client,
        launcher: launcher,
        windowService: windowService,
        trayService: trayService,
      ).read(appLifecycleControllerProvider);
      await flushMicrotasks();

      trayService.onAction?.call(TrayAction.quit);
      await flushMicrotasks();

      expect(client.shutdownForceCalls, isEmpty);
      expect(windowService.exitCount, 1);
    });

    test(
      'Stop Backend & Quit shuts down immediately when activeRuns == 0',
      () async {
        final client = _FakeBackendClient()..statusResult = Success(_status());
        final launcher = _FakeBackendLauncher();
        final windowService = _FakeWindowLifecycleService();
        final trayService = _FakeTrayService();

        final container = createContainer(
          client: client,
          launcher: launcher,
          windowService: windowService,
          trayService: trayService,
        )..read(appLifecycleControllerProvider);
        await flushMicrotasks();

        trayService.onAction?.call(TrayAction.stopBackendAndQuit);
        await flushMicrotasks();

        expect(client.shutdownForceCalls, [false]);
        expect(windowService.exitCount, 1);
        expect(
          container
              .read(appLifecycleControllerProvider)
              .pendingStopConfirmation,
          isFalse,
        );
      },
    );

    test('Stop Backend & Quit prompts confirmation when activeRuns > 0 and '
        'calls shutdown(force: true) on confirm', () async {
      final client = _FakeBackendClient()
        ..statusResult = Success(_status(activeRuns: 3));
      final launcher = _FakeBackendLauncher();
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      final container = createContainer(
        client: client,
        launcher: launcher,
        windowService: windowService,
        trayService: trayService,
      )..read(appLifecycleControllerProvider);
      await flushMicrotasks();

      trayService.onAction?.call(TrayAction.stopBackendAndQuit);
      await flushMicrotasks();

      expect(windowService.showCount, 1);
      expect(client.shutdownForceCalls, isEmpty);
      expect(windowService.exitCount, 0);

      final state = container.read(appLifecycleControllerProvider);
      expect(state.pendingStopConfirmation, isTrue);
      expect(state.activeRunsForConfirmation, 3);

      await container
          .read(appLifecycleControllerProvider.notifier)
          .confirmStopBackendAndQuit();
      await flushMicrotasks();

      expect(client.shutdownForceCalls, [true]);
      expect(windowService.exitCount, 1);
    });

    test('cancelStopBackendAndQuit clears confirmation without exit', () async {
      final client = _FakeBackendClient()
        ..statusResult = Success(_status(activeRuns: 1));
      final launcher = _FakeBackendLauncher();
      final windowService = _FakeWindowLifecycleService();
      final trayService = _FakeTrayService();

      final container = createContainer(
        client: client,
        launcher: launcher,
        windowService: windowService,
        trayService: trayService,
      )..read(appLifecycleControllerProvider);
      await flushMicrotasks();

      trayService.onAction?.call(TrayAction.stopBackendAndQuit);
      await flushMicrotasks();

      container
          .read(appLifecycleControllerProvider.notifier)
          .cancelStopBackendAndQuit();

      expect(
        container.read(appLifecycleControllerProvider).pendingStopConfirmation,
        isFalse,
      );
      expect(client.shutdownForceCalls, isEmpty);
      expect(windowService.exitCount, 0);
    });

    test(
      'disposes tray and window services before exitApplication and does not '
      'cancel re-emitted quit request when exiting (macOS Cmd+Q regression)',
      () async {
        final events = <String>[];
        final client = _FakeBackendClient()..statusResult = Success(_status());
        final launcher = _FakeBackendLauncher();
        late final _FakeWindowLifecycleService windowService;
        windowService = _FakeWindowLifecycleService(
          events: events,
          onExitApplication: () {
            // Simulate Application.quit(0) re-emitting
            // ApplicationQuitRequestedEvent synchronously during exit.
            windowService.simulateOsQuitRequest();
          },
        );
        final trayService = _FakeTrayService(events: events);

        createContainer(
          client: client,
          launcher: launcher,
          windowService: windowService,
          trayService: trayService,
        ).read(appLifecycleControllerProvider);
        await flushMicrotasks();

        // Initial OS quit request (e.g. macOS Cmd+Q) is intercepted and starts
        // the graceful quit sequence.
        final initialCompleted = windowService.simulateOsQuitRequest();
        expect(initialCompleted, isFalse);
        await flushMicrotasks();

        expect(client.shutdownForceCalls, [false]);
        expect(trayService.disposed, isTrue);
        expect(windowService.disposed, isTrue);
        expect(windowService.exitCount, 1);
        expect(events, [
          'osQuitCancelled',
          'tray.dispose',
          'window.dispose',
          'window.exitApplication',
          'osQuitCompleted',
        ]);
      },
    );

    test('NativeWindowLifecycleService sets isExiting and does not cancel quit '
        'event once exitApplication has started', () async {
      var quitCode = -1;
      final service = MacOSWindowLifecycleService(
        quitRunner: (code) {
          quitCode = code;
        },
      );
      expect(service.isExiting, isFalse);

      await service.exitApplication();

      expect(service.isExiting, isTrue);
      expect(quitCode, 0);
    });
  });
}
