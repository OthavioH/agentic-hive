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

import 'fake_pause_repository.dart';

final DateTime _now = DateTime.utc(2026, 11, 21, 10);

Pause _pause({
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
  createdAt: _now,
  title: 'Approve?',
  parentRunId: parentRunId,
);

Future<void> _pumpPauses(
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
      overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
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
  testWidgets('child pause row shows "In run <short id>"', (tester) async {
    final repo = FakePauseRepository(
      initial: <Pause>[
        _pause(id: 'p-1', runId: 'child-run-1', parentRunId: 'abcdef123456'),
      ],
    );
    addTearDown(repo.dispose);

    await _pumpPauses(tester, repo);

    expect(find.byKey(const Key('pause_parent_link_p-1')), findsOneWidget);
    expect(find.text('In run abcdef12'), findsOneWidget);
  });

  testWidgets('a short parent id is shown whole', (tester) async {
    final repo = FakePauseRepository(
      initial: <Pause>[
        _pause(id: 'p-short', runId: 'child-run-1', parentRunId: 'run-p'),
      ],
    );
    addTearDown(repo.dispose);

    await _pumpPauses(tester, repo);

    expect(find.byKey(const Key('pause_parent_link_p-short')), findsOneWidget);
    expect(find.text('In run run-p'), findsOneWidget);
  });

  testWidgets('an ordinary pause shows no parent line', (tester) async {
    final repo = FakePauseRepository(
      initial: <Pause>[_pause(id: 'p-plain', runId: 'run-1')],
    );
    addTearDown(repo.dispose);

    await _pumpPauses(tester, repo);

    expect(find.byKey(const Key('pause_parent_link_p-plain')), findsNothing);
    expect(find.textContaining('In run'), findsNothing);
  });

  testWidgets(
    'selecting a child pause shows "Open parent run" and it opens the parent',
    (tester) async {
      final navigated = <String>[];
      final repo = FakePauseRepository(
        initial: <Pause>[
          _pause(id: 'p-1', runId: 'child-run-1', parentRunId: 'abcdef123456'),
        ],
      );
      addTearDown(repo.dispose);

      await _pumpPauses(tester, repo, navigated: navigated);

      expect(
        find.byKey(const Key('pauses_open_parent_run_button')),
        findsOneWidget,
      );
      expect(find.text('Open parent run'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pauses_open_parent_run_button')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/runs/abcdef123456']);
    },
  );

  testWidgets('an ordinary pause has no parent button', (tester) async {
    final repo = FakePauseRepository(
      initial: <Pause>[_pause(id: 'p-plain', runId: 'run-1')],
    );
    addTearDown(repo.dispose);

    await _pumpPauses(tester, repo);

    expect(
      find.byKey(const Key('pauses_open_parent_run_button')),
      findsNothing,
    );
  });

  testWidgets('the existing "Open run" button still opens the child run', (
    tester,
  ) async {
    final navigated = <String>[];
    final repo = FakePauseRepository(
      initial: <Pause>[
        _pause(id: 'p-1', runId: 'child-run-1', parentRunId: 'abcdef123456'),
      ],
    );
    addTearDown(repo.dispose);

    await _pumpPauses(tester, repo, navigated: navigated);

    await tester.tap(find.byKey(const Key('pauses_open_run_button')));
    await tester.pumpAndSettle();

    expect(navigated, <String>['/runs/child-run-1']);
  });
}
