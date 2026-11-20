import 'dart:io';

import 'package:agentic_hive_frontend/app.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
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

final class _FakeBackendClient implements BackendClient {
  @override
  Future<Result<HealthResponse>> checkHealth() async =>
      const Success<HealthResponse>(HealthResponse());

  @override
  Future<Result<WebSocket>> connectWebSocket() async =>
      const FailureResult<WebSocket>(NetworkFailure('Unused in router tests'));

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
