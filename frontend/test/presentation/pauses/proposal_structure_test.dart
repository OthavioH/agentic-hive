import 'dart:io';

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
import 'package:material_ui/material_ui.dart';

import 'fake_pause_repository.dart';

void main() {
  const desktopSize = Size(1440, 900);

  void configureDesktop(WidgetTester tester) {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPausesPage(WidgetTester tester, FakePauseRepository repo) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: HiveTheme.dark(),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: PausesPage()),
        ),
      ),
    );
  }

  Pause makeApproval({
    String id = 'pause-approval',
    DateTime? createdAt,
    Object? proposal,
    String? proposalSource,
    String? proposalSchema,
  }) => Pause(
    id: id,
    runId: 'run-42',
    nodeId: 'node-approve',
    kind: PauseKind.humanApproval,
    status: PauseStatus.pending,
    workflowName: 'Release Workflow',
    nodeLabel: 'Manual Gate',
    createdAt: createdAt ?? DateTime.utc(2026, 11, 21, 10),
    title: 'Proceed with release?',
    instructions: 'Verify all artifacts before approving.',
    proposal: proposal,
    proposalSource: proposalSource,
    proposalSchema: proposalSchema,
  );

  File resolveRepoFile(String frontendRelative) {
    for (final candidate in <String>[
      frontendRelative,
      'frontend/$frontendRelative',
    ]) {
      final file = File(candidate);
      if (file.existsSync()) return file;
    }
    throw StateError(
      'Could not locate $frontendRelative from ${Directory.current.path}',
    );
  }

  void expectSameRow(WidgetTester tester, Finder left, Finder right) {
    final leftCenterY = tester.getCenter(left).dy;
    final rightCenterY = tester.getCenter(right).dy;
    expect(leftCenterY, closeTo(rightCenterY, 1.0));
    expect(tester.getTopLeft(left).dx, lessThan(tester.getTopLeft(right).dx));
  }

  void expectStrictlyIncreasingTops(WidgetTester tester, List<Finder> finders) {
    final tops = <double>[
      for (final finder in finders) tester.getTopLeft(finder).dy,
    ];
    for (var i = 0; i < tops.length - 1; i++) {
      expect(
        tops[i],
        lessThan(tops[i + 1]),
        reason:
            'element $i (dy=${tops[i]}) must precede ${i + 1} '
            '(dy=${tops[i + 1]})',
      );
    }
  }

  group('PauseDetailPane approval proposal structure guard', () {
    const editButtonKey = Key('pauses_proposal_edit_button');
    const discardButtonKey = Key('pauses_proposal_discard_button');
    const viewKey = Key('pauses_proposal_view');
    const editorKey = Key('pauses_proposal_field');
    const feedbackKey = Key('pauses_feedback_field');
    const rejectKey = Key('pauses_reject_button');
    const approveKey = Key('pauses_approve_button');

    testWidgets('read-only order', (tester) async {
      configureDesktop(tester);
      final repo = FakePauseRepository(
        initial: <Pause>[
          makeApproval(
            proposal: const <String, Object?>{'step': 1},
            proposalSource: 'planner',
          ),
        ],
      );
      addTearDown(repo.dispose);

      await pumpPausesPage(tester, repo);
      await tester.pumpAndSettle();

      final headingFinder = find.text('Proposal from planner');
      final editFinder = find.byKey(editButtonKey);
      final viewFinder = find.byKey(viewKey);
      final feedbackFinder = find.byKey(feedbackKey);
      final rejectFinder = find.byKey(rejectKey);
      final approveFinder = find.byKey(approveKey);

      expectSameRow(tester, headingFinder, editFinder);
      expectStrictlyIncreasingTops(tester, <Finder>[
        headingFinder,
        viewFinder,
        feedbackFinder,
        rejectFinder,
      ]);
      expect(
        tester.getTopLeft(editFinder).dy,
        lessThan(tester.getTopLeft(viewFinder).dy),
      );
      expectSameRow(tester, rejectFinder, approveFinder);
    });

    testWidgets('editing order', (tester) async {
      configureDesktop(tester);
      final repo = FakePauseRepository(
        initial: <Pause>[
          makeApproval(
            proposal: const <String, Object?>{'step': 1},
            proposalSource: 'planner',
          ),
        ],
      );
      addTearDown(repo.dispose);

      await pumpPausesPage(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(editButtonKey));
      await tester.pumpAndSettle();

      final headingFinder = find.text('Proposal from planner');
      final discardFinder = find.byKey(discardButtonKey);
      final editorFinder = find.byKey(editorKey);
      final feedbackFinder = find.byKey(feedbackKey);
      final rejectFinder = find.byKey(rejectKey);
      final approveFinder = find.byKey(approveKey);

      expect(find.byKey(editButtonKey), findsNothing);
      expect(find.byKey(viewKey), findsNothing);
      expectSameRow(tester, headingFinder, discardFinder);
      expectStrictlyIncreasingTops(tester, <Finder>[
        headingFinder,
        editorFinder,
        feedbackFinder,
        rejectFinder,
      ]);
      expect(
        tester.getTopLeft(discardFinder).dy,
        lessThan(tester.getTopLeft(editorFinder).dy),
      );
      expectSameRow(tester, rejectFinder, approveFinder);
      expect(find.text('Approve edited proposal'), findsOneWidget);
    });

    testWidgets('no proposal', (tester) async {
      configureDesktop(tester);
      final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
      addTearDown(repo.dispose);

      await pumpPausesPage(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byKey(viewKey), findsNothing);
      expect(find.byKey(editButtonKey), findsNothing);
      expect(find.byKey(discardButtonKey), findsNothing);
      expect(find.byKey(editorKey), findsNothing);
      expect(find.textContaining('Proposal'), findsNothing);
    });

    testWidgets('proposal heading is a semantic header', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        configureDesktop(tester);
        final repo = FakePauseRepository(
          initial: <Pause>[
            makeApproval(
              proposal: const <String, Object?>{'ok': true},
              proposalSource: 'planner',
            ),
          ],
        );
        addTearDown(repo.dispose);

        await pumpPausesPage(tester, repo);
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(
          find.text('Proposal from planner'),
        );
        expect(semantics.getSemanticsData().flagsCollection.isHeader, isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('invalid state copy', (tester) async {
      configureDesktop(tester);
      final repo = FakePauseRepository(
        initial: <Pause>[
          makeApproval(
            proposal: const <String, Object?>{'ok': true},
            proposalSource: 'planner',
          ),
        ],
      );
      addTearDown(repo.dispose);

      await pumpPausesPage(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(editButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(editorKey), '{bad');
      await tester.pumpAndSettle();

      expect(find.textContaining('Not valid JSON'), findsOneWidget);
      expect(
        tester.widget<HiveButton>(find.byKey(approveKey)).onPressed,
        isNull,
      );
      expect(
        tester.widget<HiveButton>(find.byKey(rejectKey)).onPressed,
        isNotNull,
      );
    });

    test('token-only guard', () {
      const approvalFormPath =
          'lib/presentation/workflows/widgets/node_config_forms/'
          'human_approval_config_form.dart';
      const paths = <String>[
        'lib/presentation/pauses/widgets/pause_detail_pane.dart',
        approvalFormPath,
      ];
      final bannedPatterns = <RegExp>[
        RegExp(r'Color\(0x'),
        RegExp(r'\bColors\.'),
        RegExp(r'EdgeInsets\.[a-zA-Z]+\(\s*\d'),
        RegExp(r'SizedBox\((width|height):\s*\d'),
        RegExp(r'BorderRadius\.circular\(\s*\d'),
        RegExp(r'fontSize:\s*\d'),
        RegExp(r'Duration\('),
      ];
      for (final path in paths) {
        final source = resolveRepoFile(path).readAsStringSync();
        for (final pattern in bannedPatterns) {
          expect(
            pattern.hasMatch(source),
            isFalse,
            reason: '$path matched banned literal ${pattern.pattern}',
          );
        }
        expect(source.contains('package:flutter/material.dart'), isFalse);
        expect(source.contains('hugeicons'), isFalse);
      }
    });
  });
}
