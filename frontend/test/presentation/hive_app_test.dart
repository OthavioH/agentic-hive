import 'dart:io';

import 'package:agentic_hive_frontend/app.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/agents/pages/agents_page.dart';
import 'package:agentic_hive_frontend/presentation/connecting/pages/connecting_page.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/pages/harnesses_page.dart';
import 'package:agentic_hive_frontend/presentation/overview/pages/overview_page.dart';
import 'package:agentic_hive_frontend/presentation/pauses/pages/pauses_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_frontend/presentation/settings/pages/settings_page.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeBackendClient implements BackendClient {
  new({required this.healthResult});

  Result<HealthResponse> healthResult;
  int healthCheckCount = 0;

  @override
  Future<Result<HealthResponse>> checkHealth() async {
    healthCheckCount++;
    return healthResult;
  }

  @override
  Future<Result<WebSocket>> connectWebSocket() async =>
      const FailureResult<WebSocket>(NetworkFailure('Unused in widget tests'));

  @override
  Future<void> close() async {}
}

void main() {
  const desktopSize = Size(1440, 900);
  const okHealth = Success<HealthResponse>(HealthResponse());
  const downHealth = FailureResult<HealthResponse>(
    NetworkFailure('Backend unreachable'),
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
        final fakeClient = _FakeBackendClient(healthResult: okHealth);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [backendClientProvider.overrideWithValue(fakeClient)],
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
          expect(find.byType(HiveEmptyState), findsOneWidget);
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
        final fakeClient = _FakeBackendClient(healthResult: downHealth);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [backendClientProvider.overrideWithValue(fakeClient)],
            child: const HiveApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ConnectingPage), findsOneWidget);
        expect(find.byType(HiveSideRail), findsNothing);
        final initialChecks = fakeClient.healthCheckCount;

        await tester.tap(find.byType(HiveButton));
        await tester.pumpAndSettle();

        expect(fakeClient.healthCheckCount, greaterThan(initialChecks));
        expect(find.byType(ConnectingPage), findsOneWidget);
      },
    );

    testWidgets(
      'disconnecting redirects to /connecting and reconnecting restores route',
      (tester) async {
        configureDesktopWindow(tester);
        final fakeClient = _FakeBackendClient(healthResult: okHealth);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [backendClientProvider.overrideWithValue(fakeClient)],
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
        fakeClient.healthResult = downHealth;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HiveApp)),
        );
        await container
            .read(backendConnectionProvider.notifier)
            .checkConnection();
        await tester.pumpAndSettle();

        expect(find.byType(ConnectingPage), findsOneWidget);
        expect(find.byType(HiveSideRail), findsNothing);

        // Transition back to connected via retry -> restores /workflows.
        fakeClient.healthResult = okHealth;
        await tester.tap(find.byType(HiveButton));
        await tester.pumpAndSettle();

        expect(find.byType(WorkflowsPage), findsOneWidget);
        expect(find.byType(HiveSideRail), findsOneWidget);
      },
    );
  });
}
