import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/connecting/pages/connecting_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              backendClientProvider.overrideWithValue(fake),
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
            backendClientProvider.overrideWithValue(fake),
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
      expect(fake.statusCalls, 2);
    });
  });
}
