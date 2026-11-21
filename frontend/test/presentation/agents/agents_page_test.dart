import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
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

final class _FakeAgentRepository implements AgentRepository {
  new({List<AgentDetail>? initial}) {
    for (final item in initial ?? const <AgentDetail>[]) {
      _store[item.id] = item;
    }
  }

  final Map<String, AgentDetail> _store = <String, AgentDetail>{};
  final StreamController<AgentsChangedPayload> _changes =
      StreamController<AgentsChangedPayload>.broadcast();
  bool triggerConflictOnNextUpdate = false;

  @override
  Future<Result<List<AgentSummary>>> listAgents() async => Success(
    _store.values
        .map(
          (d) => AgentSummary(
            id: d.id,
            name: d.name,
            description: d.description,
            tags: d.tags,
            contentHash: d.contentHash,
            updatedAt: d.updatedAt,
            parseError: d.parseError,
          ),
        )
        .toList(),
  );

  @override
  Future<Result<AgentDetail>> getAgent(String id) async {
    final found = _store[id];
    if (found == null) {
      return const FailureResult(NotFoundFailure('Not found'));
    }
    return Success(found);
  }

  @override
  Future<Result<AgentDetail>> createAgent(CreateAgentRequest request) async {
    final detail = AgentDetail(
      id: request.id,
      name: request.name,
      description: request.description,
      tags: request.tags,
      requiredSkills: request.requiredSkills,
      requiredTools: request.requiredTools,
      allowedTools: request.allowedTools,
      deniedTools: request.deniedTools,
      prompt: request.prompt,
      contentHash: 'hash-${request.id}-1',
      updatedAt: DateTime.utc(2026, 11, 20),
    );
    _store[detail.id] = detail;
    return Success(detail);
  }

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request,
  ) async {
    if (triggerConflictOnNextUpdate) {
      triggerConflictOnNextUpdate = false;
      return const FailureResult(
        BackendFailure(
          'Conflict on disk',
          code: ApiErrorCode.conflict,
          statusCode: 409,
        ),
      );
    }
    final existing = _store[id]!;
    final updated = existing.copyWith(
      name: request.name,
      description: request.description,
      tags: request.tags,
      requiredSkills: request.requiredSkills,
      requiredTools: request.requiredTools,
      allowedTools: request.allowedTools,
      deniedTools: request.deniedTools,
      prompt: request.prompt,
      contentHash: '${existing.contentHash}-2',
    );
    _store[id] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteAgent(String id) async {
    _store.remove(id);
    return const Success(null);
  }

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() => _changes.stream;

  Future<void> dispose() => _changes.close();
}

void main() {
  const desktopSize = Size(1440, 900);

  void configureDesktop(WidgetTester tester) {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpAgentsPage(WidgetTester tester, _FakeAgentRepository repo) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [agentRepositoryProvider.overrideWithValue(repo)],
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
  }

  final reviewer = AgentDetail(
    id: 'reviewer',
    name: 'Code Reviewer',
    description: 'Checks PR quality',
    tags: const <String>['qa'],
    contentHash: 'h1',
    updatedAt: DateTime.utc(2026, 11, 20),
    prompt: '## Role\n\nReview code.',
  );

  final broken = AgentDetail(
    id: 'broken-agent',
    name: 'broken-agent',
    contentHash: 'h2',
    updatedAt: DateTime.utc(2026, 11, 20),
    parseError: 'Missing closing frontmatter delimiter',
    rawContent: '---\nname: Broken',
  );

  group('AgentsPage', () {
    testWidgets(
      'renders list, filters by search and tag, and toggles Raw/Preview',
      (tester) async {
        configureDesktop(tester);
        final repo = _FakeAgentRepository(
          initial: <AgentDetail>[reviewer, broken],
        );
        addTearDown(repo.dispose);

        await pumpAgentsPage(tester, repo);
        await tester.pumpAndSettle();

        expect(find.text('Code Reviewer'), findsOneWidget);
        expect(find.text('broken-agent'), findsAtLeastNWidgets(1));
        expect(find.text('Parse error'), findsOneWidget);

        // Filter by tag chip 'qa'.
        await tester.tap(find.widgetWithText(HiveFilterChip, 'qa'));
        await tester.pumpAndSettle();
        expect(find.text('Code Reviewer'), findsOneWidget);
        expect(find.text('broken-agent'), findsNothing);

        // Select reviewer and toggle Preview mode.
        await tester.tap(find.text('Code Reviewer'));
        await tester.pumpAndSettle();

        expect(find.byType(HiveTextArea), findsOneWidget);
        await tester.tap(find.text('Preview'));
        await tester.pumpAndSettle();
        expect(find.byType(HiveMarkdownView), findsOneWidget);
      },
    );

    testWidgets('creates a new agent inline with auto-slug and template', (
      tester,
    ) async {
      configureDesktop(tester);
      final repo = _FakeAgentRepository();
      addTearDown(repo.dispose);

      await pumpAgentsPage(tester, repo);
      await tester.pumpAndSettle();

      // Empty state shows New agent button (plus header button).
      await tester.tap(find.text('New agent').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(HiveTextField, 'Name'),
        'Release Manager',
      );
      await tester.pumpAndSettle();
      expect(find.text('release-manager'), findsOneWidget);

      await tester.tap(find.text('Insert template'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Agent created.'), findsOneWidget);
      expect(find.text('Release Manager'), findsAtLeastNWidgets(1));
      await tester.pump(HiveToast.defaultDisplayDuration);
    });

    testWidgets('inspects parseError and deletes after confirmation dialog', (
      tester,
    ) async {
      configureDesktop(tester);
      final repo = _FakeAgentRepository(initial: <AgentDetail>[broken]);
      addTearDown(repo.dispose);

      await pumpAgentsPage(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('broken-agent').first);
      await tester.pumpAndSettle();

      expect(find.text('Unable to parse agent file'), findsOneWidget);
      expect(
        find.text('Missing closing frontmatter delimiter'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete agent?'), findsOneWidget);

      await tester.tap(find.widgetWithText(HiveButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Agent deleted.'), findsOneWidget);
      expect(find.text('No agents configured'), findsOneWidget);
      await tester.pump(HiveToast.defaultDisplayDuration);
    });

    testWidgets('shows 409 conflict dialog and overwrites on confirm', (
      tester,
    ) async {
      configureDesktop(tester);
      final repo = _FakeAgentRepository(initial: <AgentDetail>[reviewer]);
      addTearDown(repo.dispose);

      await pumpAgentsPage(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Code Reviewer'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(HiveTextField, 'Description'),
        'Updated description',
      );
      await tester.pumpAndSettle();

      repo.triggerConflictOnNextUpdate = true;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('External modification detected'), findsOneWidget);
      expect(find.text('Reload from disk'), findsOneWidget);
      expect(find.text('Overwrite'), findsOneWidget);

      await tester.tap(find.text('Overwrite'));
      await tester.pumpAndSettle();
      expect(find.text('Agent saved.'), findsOneWidget);
      await tester.pump(HiveToast.defaultDisplayDuration);
    });
  });
}
