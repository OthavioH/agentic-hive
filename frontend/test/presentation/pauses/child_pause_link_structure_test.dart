import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/pauses/pages/pauses_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import 'fake_pause_repository.dart';

Pause _makeApproval({
  required String id,
  required String runId,
  String? parentRunId,
}) => Pause(
  id: id,
  runId: runId,
  nodeId: 'node-approve',
  kind: PauseKind.humanApproval,
  status: PauseStatus.pending,
  workflowName: 'Child Workflow',
  nodeLabel: 'Review Gate',
  createdAt: DateTime.utc(2026, 11, 21, 10),
  title: 'Approve?',
  parentRunId: parentRunId,
);

Future<void> _pumpPausesPage(
  WidgetTester tester,
  FakePauseRepository repo, {
  List<String>? navigated,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/pauses',
    routes: <RouteBase>[
      GoRoute(
        path: '/pauses',
        builder: (_, _) => const Scaffold(body: PausesPage()),
      ),
      GoRoute(
        path: '/runs/:id',
        builder: (_, state) {
          navigated?.add('/runs/${state.pathParameters['id']}');
          return Scaffold(body: Text('run:${state.pathParameters['id']}'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[pauseRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        theme: HiveTheme.dark(),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Child pause link structure guards', () {
    testWidgets('child pause shows parent link in list and button in detail', (
      tester,
    ) async {
      final repo = FakePauseRepository(
        initial: <Pause>[
          _makeApproval(
            id: 'p-1',
            runId: 'child-run-1',
            parentRunId: 'parent-run-12345',
          ),
        ],
      );
      addTearDown(repo.dispose);

      await _pumpPausesPage(tester, repo);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PausesPage)),
      )!;
      const listLinkKey = Key('pause_parent_link_p-1');
      expect(find.byKey(listLinkKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(listLinkKey)).data,
        l10n.pausesChildOfRun('parent-r'),
      );

      const openButtonKey = Key('pauses_open_run_button');
      const openParentKey = Key('pauses_open_parent_run_button');
      expect(find.byKey(openButtonKey), findsOneWidget);
      expect(find.byKey(openParentKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(openParentKey),
          matching: find.text(l10n.pausesOpenParentRunAction),
        ),
        findsOneWidget,
      );

      final openDx = tester.getTopLeft(find.byKey(openButtonKey)).dx;
      final parentDx = tester.getTopLeft(find.byKey(openParentKey)).dx;
      expect(parentDx, greaterThan(openDx));
    });

    testWidgets('parent link line sits below the node label in the list row', (
      tester,
    ) async {
      final repo = FakePauseRepository(
        initial: <Pause>[
          _makeApproval(
            id: 'p-1',
            runId: 'child-run-1',
            parentRunId: 'parent-run-12345',
          ),
        ],
      );
      addTearDown(repo.dispose);

      await _pumpPausesPage(tester, repo);

      final listItem = find.byKey(const Key('pause_list_item_p-1'));
      final nodeLabel = find.descendant(
        of: listItem,
        matching: find.text('Review Gate'),
      );
      final parentLink = find.byKey(const Key('pause_parent_link_p-1'));

      expect(
        tester.getTopLeft(parentLink).dy,
        greaterThan(tester.getTopLeft(nodeLabel).dy),
      );
    });

    testWidgets('pause without parent has neither', (tester) async {
      final repo = FakePauseRepository(
        initial: <Pause>[_makeApproval(id: 'p-plain', runId: 'run-1')],
      );
      addTearDown(repo.dispose);

      await _pumpPausesPage(tester, repo);

      expect(find.byKey(const Key('pause_parent_link_p-plain')), findsNothing);
      expect(
        find.byKey(const Key('pauses_open_parent_run_button')),
        findsNothing,
      );
    });

    testWidgets('open buttons navigate', (tester) async {
      final navigated = <String>[];
      final repo = FakePauseRepository(
        initial: <Pause>[
          _makeApproval(
            id: 'p-1',
            runId: 'child-run-1',
            parentRunId: 'parent-run-12345',
          ),
        ],
      );
      addTearDown(repo.dispose);

      await _pumpPausesPage(tester, repo, navigated: navigated);

      await tester.tap(find.byKey(const Key('pauses_open_parent_run_button')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/runs/parent-run-12345']);
    });
  });
}
