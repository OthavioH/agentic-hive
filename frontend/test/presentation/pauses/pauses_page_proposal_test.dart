import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
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

  testWidgets('R1: approval without proposal hides proposal view and sends '
      'null proposal', (tester) async {
    configureDesktop(tester);
    final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
    addTearDown(repo.dispose);

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pauses_proposal_view')), findsNothing);
    expect(find.byKey(const Key('pauses_proposal_edit_button')), findsNothing);

    await tester.tap(find.byKey(const Key('pauses_approve_button')));
    await tester.pumpAndSettle();

    expect(repo.recordedAnswers.single.request.decision, 'approved');
    expect(repo.recordedAnswers.single.request.proposal, isNull);
  });

  testWidgets('R2: approval with proposal renders pretty JSON and approves '
      'unchanged without proposal field', (tester) async {
    configureDesktop(tester);
    final repo = FakePauseRepository(
      initial: <Pause>[
        makeApproval(
          proposal: const <String, Object?>{
            'items': <int>[1, 2],
          },
          proposalSource: 'planner',
        ),
      ],
    );
    addTearDown(repo.dispose);

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Proposal from planner'), findsOneWidget);
    final view = tester.widget<HiveCodeBlock>(
      find.byKey(const Key('pauses_proposal_view')),
    );
    expect(view.code, contains('  "items": ['));
    expect(
      find.byKey(const Key('pauses_proposal_edit_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('pauses_approve_button')));
    await tester.pumpAndSettle();

    expect(repo.recordedAnswers.single.request.decision, 'approved');
    expect(repo.recordedAnswers.single.request.proposal, isNull);
  });

  testWidgets('R2: null proposalSource uses generic Proposal heading', (
    tester,
  ) async {
    configureDesktop(tester);
    final repo = FakePauseRepository(
      initial: <Pause>[
        makeApproval(proposal: const <String, Object?>{'ok': true}),
      ],
    );
    addTearDown(repo.dispose);

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Proposal'), findsOneWidget);
  });

  testWidgets('R3/R5: editing switches to editor, discard restores read-only, '
      'and valid edit sends decoded proposal', (tester) async {
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

    await tester.tap(find.byKey(const Key('pauses_proposal_edit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pauses_proposal_field')), findsOneWidget);
    expect(
      tester
          .widget<HiveTextArea>(find.byKey(const Key('pauses_proposal_field')))
          .controller!
          .text,
      '{\n  "step": 1\n}',
    );
    expect(find.text('Approve edited proposal'), findsOneWidget);
    expect(
      find.byKey(const Key('pauses_proposal_discard_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('pauses_proposal_discard_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pauses_proposal_field')), findsNothing);
    expect(find.byKey(const Key('pauses_proposal_view')), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pauses_proposal_edit_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pauses_proposal_field')),
      '[1, 2]',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pauses_approve_button')));
    await tester.pumpAndSettle();

    expect(repo.recordedAnswers.single.request.decision, 'approved');
    expect(repo.recordedAnswers.single.request.proposal, <int>[1, 2]);
  });

  testWidgets('R4/R6: invalid JSON or schema error disables Approve while '
      'keeping Reject enabled without proposal', (tester) async {
    configureDesktop(tester);
    final repo = FakePauseRepository(
      initial: <Pause>[
        makeApproval(
          proposal: const <int>[1],
          proposalSource: 'planner',
          proposalSchema: '{"type":"array"}',
        ),
      ],
    );
    addTearDown(repo.dispose);

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pauses_proposal_edit_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('pauses_proposal_field')),
      '{bad',
    );
    await tester.pumpAndSettle();

    final editorInvalidJson = tester.widget<HiveTextArea>(
      find.byKey(const Key('pauses_proposal_field')),
    );
    expect(editorInvalidJson.errorText, contains('Not valid JSON'));
    expect(
      tester
          .widget<HiveButton>(find.byKey(const Key('pauses_approve_button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<HiveButton>(find.byKey(const Key('pauses_reject_button')))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(
      find.byKey(const Key('pauses_proposal_field')),
      '{}',
    );
    await tester.pumpAndSettle();

    final editorSchemaFail = tester.widget<HiveTextArea>(
      find.byKey(const Key('pauses_proposal_field')),
    );
    expect(editorSchemaFail.errorText, isNotNull);
    expect(
      tester
          .widget<HiveButton>(find.byKey(const Key('pauses_approve_button')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('pauses_proposal_field')),
      '[]',
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<HiveTextArea>(find.byKey(const Key('pauses_proposal_field')))
          .errorText,
      isNull,
    );
    expect(
      tester
          .widget<HiveButton>(find.byKey(const Key('pauses_approve_button')))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(
      find.byKey(const Key('pauses_proposal_field')),
      '{bad',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pauses_reject_button')));
    await tester.pumpAndSettle();

    expect(repo.recordedAnswers.single.request.decision, 'rejected');
    expect(repo.recordedAnswers.single.request.proposal, isNull);
  });

  testWidgets('R7: submitting disables editor and actions and shows '
      'Submitting...', (tester) async {
    configureDesktop(tester);
    final repo = FakePauseRepository(
      initial: <Pause>[
        makeApproval(proposal: const <int>[1], proposalSource: 'planner'),
      ],
    );
    addTearDown(repo.dispose);

    final completer = Completer<Result<Pause>>();
    repo.onAnswerPause = (_, _) => completer.future;

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pauses_proposal_edit_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pauses_approve_button')));
    await tester.pump();

    final approveButton = tester.widget<HiveButton>(
      find.byKey(const Key('pauses_approve_button')),
    );
    final rejectButton = tester.widget<HiveButton>(
      find.byKey(const Key('pauses_reject_button')),
    );
    final discardButton = tester.widget<HiveButton>(
      find.byKey(const Key('pauses_proposal_discard_button')),
    );
    final editor = tester.widget<HiveTextArea>(
      find.byKey(const Key('pauses_proposal_field')),
    );

    expect(approveButton.label, 'Submitting...');
    expect(approveButton.loading, isTrue);
    expect(rejectButton.onPressed, isNull);
    expect(discardButton.onPressed, isNull);
    expect(editor.enabled, isFalse);

    completer.complete(
      Success(makeApproval().copyWith(status: PauseStatus.answered)),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('R8: backend refusal shows message in error banner, keeps '
      'editor/draft, and allows retry', (tester) async {
    configureDesktop(tester);
    final pause = makeApproval(
      proposal: const <int>[1],
      proposalSource: 'planner',
    );
    final repo = FakePauseRepository(initial: <Pause>[pause]);
    addTearDown(repo.dispose);

    var failFirst = true;
    repo.onAnswerPause = (_, _) async {
      if (failFirst) {
        failFirst = false;
        return const FailureResult(
          BackendFailure('Proposal does not match the schema'),
        );
      }
      return Success(pause.copyWith(status: PauseStatus.answered));
    };

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pauses_proposal_edit_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pauses_proposal_field')),
      '[2]',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pauses_approve_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pauses_submit_error_banner')), findsOneWidget);
    expect(find.text('Proposal does not match the schema'), findsOneWidget);
    expect(find.byKey(const Key('pauses_proposal_field')), findsOneWidget);
    expect(
      tester
          .widget<HiveTextArea>(find.byKey(const Key('pauses_proposal_field')))
          .controller!
          .text,
      '[2]',
    );

    await tester.tap(find.byKey(const Key('pauses_approve_button')));
    await tester.pumpAndSettle();

    expect(repo.recordedAnswers, hasLength(2));
    expect(repo.recordedAnswers[1].request.proposal, <int>[2]);
    expect(find.text('No pending pauses'), findsOneWidget);
  });

  testWidgets('R9: switching between pauses preserves editing mode and draft', (
    tester,
  ) async {
    configureDesktop(tester);
    final p1 = makeApproval(
      id: 'pause-1',
      createdAt: DateTime.utc(2026, 11, 21, 10),
      proposal: const <String, Object?>{'a': 1},
      proposalSource: 'planner',
    );
    final p2 = makeApproval(
      id: 'pause-2',
      createdAt: DateTime.utc(2026, 11, 21, 11),
      proposal: const <String, Object?>{'b': 2},
      proposalSource: 'reviewer',
    );
    final repo = FakePauseRepository(initial: <Pause>[p1, p2]);
    addTearDown(repo.dispose);

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pauses_proposal_edit_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pauses_proposal_field')),
      '{"a": 99}',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pause_list_item_pause-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pauses_proposal_view')), findsOneWidget);
    expect(find.byKey(const Key('pauses_proposal_field')), findsNothing);

    await tester.tap(find.byKey(const Key('pause_list_item_pause-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pauses_proposal_field')), findsOneWidget);
    expect(
      tester
          .widget<HiveTextArea>(find.byKey(const Key('pauses_proposal_field')))
          .controller!
          .text,
      '{"a": 99}',
    );
  });

  testWidgets('Accessibility: proposal heading has header semantics and '
      'action buttons have usable tap targets', (tester) async {
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

    final headingSemantics = tester.getSemantics(
      find.text('Proposal from planner'),
    );
    expect(
      headingSemantics.getSemanticsData().flagsCollection.isHeader,
      isTrue,
    );

    final approveSize = tester.getSize(
      find.byKey(const Key('pauses_approve_button')),
    );
    final editSize = tester.getSize(
      find.byKey(const Key('pauses_proposal_edit_button')),
    );
    expect(approveSize.height, greaterThanOrEqualTo(32));
    expect(editSize.height, greaterThanOrEqualTo(32));
  });
}
