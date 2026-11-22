import 'dart:async';

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
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeBackendClient implements BackendClient {
  Result<StatusResponse> nextStatus = const FailureResult(
    NetworkFailure('missing', code: BackendFailureCode.notRunning),
  );
  int statusCalls = 0;

  @override
  Future<Result<StatusResponse>> checkStatus() async {
    statusCalls++;
    return nextStatus;
  }

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const Success(ShutdownResponse());

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

final class _FakeTimer implements Timer {
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _active = false;
  }
}

final class _FakeBackendLauncher implements BackendLauncher {
  @override
  Result<BackendLaunchTarget> resolveLaunchTarget() =>
      const Success(BackendLaunchTarget(executable: '/fake/backend'));

  @override
  Future<Result<void>> launch() async => const Success(null);
}

final class _FakeWindowLifecycleService implements WindowLifecycleService {
  final ValueNotifier<bool> _isMaximized = ValueNotifier<bool>(false);

  @override
  bool get hasCustomTitleBar => true;

  @override
  ValueListenable<bool> get isMaximized => _isMaximized;

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

List<Override> _baseOverrides(_FakeBackendClient fake) => [
  backendClientProvider.overrideWithValue(fake),
  backendLauncherProvider.overrideWithValue(_FakeBackendLauncher()),
  windowLifecycleServiceProvider.overrideWithValue(
    _FakeWindowLifecycleService(),
  ),
  trayServiceProvider.overrideWithValue(_FakeTrayService()),
];

Widget _buildTestApp() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: HiveTheme.light(),
  home: const ConnectingPage(),
);

void main() {
  group('ConnectingPage', () {
    for (final testCase
        in <
          ({
            Failure failure,
            String Function(AppLocalizations) title,
            String Function(AppLocalizations) message,
          })
        >[
          (
            failure: const NetworkFailure(
              'missing',
              code: BackendFailureCode.notRunning,
            ),
            title: (l10n) => l10n.connectingReasonNotRunningTitle,
            message: (l10n) => l10n.connectingReasonNotRunningMessage,
          ),
          (
            failure: const NetworkFailure(
              'refused',
              code: BackendFailureCode.connectionRefused,
            ),
            title: (l10n) => l10n.connectingReasonRefusedTitle,
            message: (l10n) => l10n.connectingReasonRefusedMessage,
          ),
          (
            failure: const BackendFailure(
              'degraded',
              code: BackendFailureCode.degraded,
              statusCode: 503,
            ),
            title: (l10n) => l10n.connectingReasonDegradedTitle,
            message: (l10n) => l10n.connectingReasonDegradedMessage,
          ),
          (
            failure: const BackendFailure(
              'mismatch',
              code: BackendFailureCode.protocolMismatch,
            ),
            title: (l10n) => l10n.connectingReasonProtocolMismatchTitle,
            message: (l10n) => l10n.connectingReasonProtocolMismatchMessage,
          ),
          (
            failure: const NetworkFailure(
              'timeout',
              code: BackendFailureCode.timeout,
            ),
            title: (l10n) => l10n.connectingReasonTimeoutTitle,
            message: (l10n) => l10n.connectingReasonTimeoutMessage,
          ),
          (
            failure: const UnexpectedFailure('boom'),
            title: (l10n) => l10n.connectingReasonUnexpectedTitle,
            message: (l10n) => l10n.connectingReasonUnexpectedMessage,
          ),
        ]) {
      testWidgets('renders localized copy for ${testCase.failure}', (
        tester,
      ) async {
        final fake = _FakeBackendClient()
          ..nextStatus = FailureResult(testCase.failure);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._baseOverrides(fake),
              backendConnectionConfigProvider.overrideWithValue(
                BackendConnectionConfig(
                  nextRandomDouble: () => 0.5,
                  now: () => DateTime.utc(2026, 11, 20),
                  createTimer: (_, _) => _FakeTimer(),
                ),
              ),
            ],
            child: _buildTestApp(),
          ),
        );
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(ConnectingPage)),
        )!;
        expect(find.text(testCase.title(l10n)), findsOneWidget);
        expect(find.text(testCase.message(l10n)), findsOneWidget);
      });
    }

    testWidgets('displays countdown state and protocolMismatch guidance', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 11, 20);
      final fake = _FakeBackendClient()
        ..nextStatus = const FailureResult(
          NetworkFailure('missing', code: BackendFailureCode.notRunning),
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._baseOverrides(fake),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(
                nextRandomDouble: () => 0.5,
                now: () => now,
                createTimer: (_, _) => _FakeTimer(),
              ),
            ),
          ],
          child: _buildTestApp(),
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ConnectingPage)),
      )!;
      expect(find.text(l10n.connectingNextRetryIn(1)), findsOneWidget);

      // Switch to protocolMismatch and trigger manual retry.
      fake.nextStatus = const FailureResult(
        BackendFailure('mismatch', code: BackendFailureCode.protocolMismatch),
      );
      await tester.tap(find.byType(HiveButton));
      await tester.pump();

      expect(find.text(l10n.connectingAutoRetryHalted), findsOneWidget);
      expect(fake.statusCalls, greaterThanOrEqualTo(2));
    });

    testWidgets('countdown tick updates Retrying in Ns cleanly every second', (
      tester,
    ) async {
      var currentNow = DateTime.utc(2026, 11, 20, 12);
      final fake = _FakeBackendClient()
        ..nextStatus = const FailureResult(
          NetworkFailure('missing', code: BackendFailureCode.notRunning),
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._baseOverrides(fake),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(
                nextRandomDouble: () => 0.5,
                now: () => currentNow,
                createTimer: (_, _) => _FakeTimer(),
              ),
            ),
          ],
          child: _buildTestApp(),
        ),
      );
      await tester.pump();

      const tickSeconds = 1;
      const tick = Duration(seconds: tickSeconds);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ConnectingPage)),
      )!;
      expect(find.text(l10n.connectingNextRetryIn(1)), findsOneWidget);

      currentNow = currentNow.add(tick);
      await tester.pump(tick);
      expect(find.text(l10n.connectingNextRetryIn(0)), findsOneWidget);
    });
  });
}
