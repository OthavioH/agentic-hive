import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/domain/agents/agents_migration_repository.dart';
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

final class _EmptyAgentRepository implements AgentRepository {
  @override
  Future<Result<List<AgentSummary>>> listAgents({
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success(<AgentSummary>[]);

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() =>
      const Stream<AgentsChangedPayload>.empty();

  @override
  Future<Result<AgentDetail>> getAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) => throw UnimplementedError();

  @override
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) => throw UnimplementedError();

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) => throw UnimplementedError();
}

final class _FakeMigrationRepository implements AgentsMigrationRepository {
  new(this.status);

  AgentsMigrationStatus status;
  Failure? dismissFailure;
  int dismissCalls = 0;

  @override
  Future<Result<AgentsMigrationStatus>> getStatus() async => Success(status);

  @override
  Future<Result<AgentsMigrationStatus>> dismiss() async {
    dismissCalls++;
    final failure = dismissFailure;
    if (failure != null) return FailureResult(failure);
    status = status.copyWith(dismissed: true);
    return Success(status);
  }
}

const _conflicts = AgentsMigrationStatus(
  legacyDir: '/data/agents',
  targetDir: '/home/me/.agents/agents',
  conflicts: <String>['reviewer.md', 'planner.md'],
);

Future<void> _pump(WidgetTester tester, _FakeMigrationRepository repo) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        agentRepositoryProvider.overrideWithValue(_EmptyAgentRepository()),
        agentsMigrationRepositoryProvider.overrideWithValue(repo),
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

void main() {
  const banner = Key('agents_migration_banner');

  testWidgets('lists the conflicts and dismisses them through the backend', (
    tester,
  ) async {
    final repo = _FakeMigrationRepository(_conflicts);
    await _pump(tester, repo);

    expect(find.byKey(banner), findsOneWidget);
    expect(find.text('reviewer.md'), findsOneWidget);
    expect(find.text('planner.md'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pumpAndSettle();

    expect(repo.dismissCalls, 1);
    expect(find.byKey(banner), findsNothing);
  });

  testWidgets('stays visible when the dismiss call fails', (tester) async {
    final repo = _FakeMigrationRepository(_conflicts)
      ..dismissFailure = const NetworkFailure('down');
    await _pump(tester, repo);

    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pumpAndSettle();

    expect(repo.dismissCalls, 1);
    expect(find.byKey(banner), findsOneWidget);
  });

  testWidgets('is hidden without conflicts or once dismissed', (tester) async {
    await _pump(
      tester,
      _FakeMigrationRepository(_conflicts.copyWith(dismissed: true)),
    );
    expect(find.byKey(banner), findsNothing);

    await _pump(
      tester,
      _FakeMigrationRepository(_conflicts.copyWith(conflicts: <String>[])),
    );
    expect(find.byKey(banner), findsNothing);
  });
}
