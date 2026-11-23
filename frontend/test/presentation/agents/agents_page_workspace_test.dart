import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/agents/pages/agents_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../workspace/fake_workspace_repository.dart';

final class _SelectionStore implements WorkspaceSelectionStore {
  @override
  Future<String?> load() async => 'ws-1';

  @override
  Future<void> save(String? workspaceId) async {}
}

AgentSummary _summary(String id, AgentScope scope, {bool overridden = false}) =>
    AgentSummary(
      id: id,
      // Same name across scopes: an override matches on the name (ADR 0025).
      name: id,
      contentHash: 'h-$id-${scope.name}',
      updatedAt: DateTime.utc(2026, 11, 22),
      scope: scope,
      overridden: overridden,
    );

final class _Repository implements AgentRepository {
  final listCalls = <String?>[];

  @override
  Future<Result<List<AgentSummary>>> listAgents({String? workspaceId}) async {
    listCalls.add(workspaceId);
    return Success([
      if (workspaceId != null) _summary('reviewer', AgentScope.workspace),
      _summary('reviewer', AgentScope.global, overridden: workspaceId != null),
      _summary('planner', AgentScope.global),
    ]);
  }

  @override
  Future<Result<AgentDetail>> getAgent(String id, {String? workspaceId}) =>
      throw UnimplementedError();

  @override
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    String? workspaceId,
  }) => throw UnimplementedError();

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    String? workspaceId,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteAgent(String id, {String? workspaceId}) =>
      throw UnimplementedError();

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() =>
      const Stream<AgentsChangedPayload>.empty();
}

void main() {
  late _Repository agents;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    agents = _Repository();
    final workspaces = FakeWorkspaceRepository(
      workspaces: [
        Workspace(
          id: 'ws-1',
          name: 'Alpha',
          rootPath: '/repos/alpha',
          isGit: true,
          createdAt: DateTime.utc(2026, 11, 22),
          updatedAt: DateTime.utc(2026, 11, 22),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentRepositoryProvider.overrideWithValue(agents),
          workspaceRepositoryProvider.overrideWithValue(workspaces),
          workspaceSelectionStoreProvider.overrideWithValue(_SelectionStore()),
        ],
        child: MaterialApp(
          theme: HiveTheme.dark(),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AgentsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a scope badge on every agent and flags overrides', (
    tester,
  ) async {
    await pump(tester);

    expect(agents.listCalls.last, 'ws-1');
    expect(find.widgetWithText(HiveBadge, 'Workspace'), findsOneWidget);
    expect(find.widgetWithText(HiveBadge, 'Global'), findsNWidgets(2));
    expect(find.widgetWithText(HiveBadge, 'Overridden'), findsOneWidget);
  });

  testWidgets('the Global entry lists only global agents', (tester) async {
    await pump(tester);
    expect(find.widgetWithText(HiveBadge, 'Workspace'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(HiveSegmentedControl<bool>),
        matching: find.text('Global'),
      ),
    );
    await tester.pumpAndSettle();

    expect(agents.listCalls.last, isNull);
    expect(find.widgetWithText(HiveBadge, 'Workspace'), findsNothing);
  });

  testWidgets('the scope control names the current workspace', (tester) async {
    await pump(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Global'), findsAtLeastNWidgets(1));
  });
}
