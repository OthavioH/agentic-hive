import 'dart:async';

import 'package:agentic_hive_frontend/app.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/error/pages/route_error_page.dart';
import 'package:agentic_hive_frontend/presentation/overview/pages/overview_page.dart';
import 'package:agentic_hive_frontend/routes/app_router_provider.dart';
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
    if (!_messages.isClosed) unawaited(_messages.close());
    if (!_done.isCompleted) _done.complete();
  }
}

final class _FakeBackendClient implements BackendClient {
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
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      Success(_FakeWebSocketSession());

  @override
  Future<void> close() async {}
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
}
