import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_controller.dart';
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

final class _FakePeriodicTimer implements Timer {
  new(this._callback);

  final void Function(Timer) _callback;
  int _tick = 0;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _tick++;
    _callback(this);
  }

  @override
  void cancel() {
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

void main() {
  const desktopSize = Size(1440, 900);

  void configureDesktop(WidgetTester tester) {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPausesPage(
    WidgetTester tester,
    FakePauseRepository repo, {
    PausesClockConfig? clockConfig,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          pauseRepositoryProvider.overrideWithValue(repo),
          if (clockConfig != null)
            pausesClockConfigProvider.overrideWithValue(clockConfig),
        ],
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

  Pause makeApproval({DateTime? createdAt}) => Pause(
    id: 'pause-approval',
    runId: 'run-42',
    nodeId: 'node-approve',
    kind: PauseKind.humanApproval,
    status: PauseStatus.pending,
    workflowName: 'Release Workflow',
    nodeLabel: 'Manual Gate',
    createdAt: createdAt ?? DateTime.utc(2026, 11, 21, 10),
    title: 'Proceed with release?',
    instructions: 'Verify all artifacts before approving.',
  );

  Pause makeQuestion({DateTime? createdAt}) => Pause(
    id: 'pause-question',
    runId: 'run-99',
    nodeId: 'node-ask',
    kind: PauseKind.askHuman,
    status: PauseStatus.pending,
    workflowName: 'Migration Assistant',
    nodeLabel: 'Choose Strategy',
    createdAt: createdAt ?? DateTime.utc(2026, 11, 21, 11),
    question: 'Which database migration strategy should be used?',
    options: const <String>['Blue-Green', 'Rolling'],
  );

  testWidgets('renders empty state when no pending pauses exist', (
    tester,
  ) async {
    configureDesktop(tester);
    final repo = FakePauseRepository();
    addTearDown(repo.dispose);

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('No pending pauses'), findsOneWidget);
    expect(
      find.text('Runs waiting for your approval or answer will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders localized error state without raw backend message and retries',
    (tester) async {
      configureDesktop(tester);
      final repo = FakePauseRepository();
      addTearDown(repo.dispose);

      var failNext = true;
      repo.onListPendingPauses = () async {
        if (failNext) {
          failNext = false;
          return const FailureResult(NetworkFailure('Raw socket error text'));
        }
        return Success(<Pause>[makeApproval()]);
      };

      await pumpPausesPage(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Unable to load pauses'), findsOneWidget);
      expect(
        find.text(
          'Could not reach the local backend. '
          'Check the connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Raw socket error text'), findsNothing);

      await tester.tap(find.byKey(const Key('pauses_retry_button')));
      await tester.pumpAndSettle();

      expect(find.text('Release Workflow'), findsWidgets);
    },
  );

  testWidgets(
    'approves and rejects humanApproval pause with optional feedback',
    (tester) async {
      configureDesktop(tester);
      final approval1 = makeApproval();
      final approval2 = approval1.copyWith(
        id: 'pause-approval-2',
        nodeLabel: 'Second Gate',
      );
      final repo = FakePauseRepository(initial: <Pause>[approval1, approval2]);
      addTearDown(repo.dispose);

      await pumpPausesPage(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Proceed with release?'), findsOneWidget);
      expect(
        find.text('Verify all artifacts before approving.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('pauses_feedback_field')),
        'Ship it',
      );
      await tester.tap(find.byKey(const Key('pauses_approve_button')));
      await tester.pumpAndSettle();

      expect(repo.recordedAnswers.first.id, 'pause-approval');
      expect(repo.recordedAnswers.first.request.decision, 'approved');
      expect(repo.recordedAnswers.first.request.feedback, 'Ship it');

      await tester.tap(find.byKey(const Key('pauses_reject_button')));
      await tester.pumpAndSettle();

      expect(repo.recordedAnswers[1].id, 'pause-approval-2');
      expect(repo.recordedAnswers[1].request.decision, 'rejected');
      expect(repo.recordedAnswers[1].request.feedback, isNull);
      expect(find.text('No pending pauses'), findsOneWidget);
    },
  );

  testWidgets(
    'ask_human chip pre-fills answer without submitting and validates blank',
    (tester) async {
      configureDesktop(tester);
      final repo = FakePauseRepository(initial: <Pause>[makeQuestion()]);
      addTearDown(repo.dispose);

      await pumpPausesPage(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pauses_submit_answer_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Please enter an answer before submitting.'),
        findsOneWidget,
      );
      expect(repo.recordedAnswers, isEmpty);

      await tester.tap(find.text('Blue-Green'));
      await tester.pumpAndSettle();
      expect(repo.recordedAnswers, isEmpty);
      expect(find.text('Blue-Green'), findsWidgets);

      await tester.enterText(
        find.byKey(const Key('pauses_answer_field')),
        'Blue-Green with canary',
      );
      await tester.tap(find.byKey(const Key('pauses_submit_answer_button')));
      await tester.pumpAndSettle();

      expect(repo.recordedAnswers.single.id, 'pause-question');
      expect(
        repo.recordedAnswers.single.request.answer,
        'Blue-Green with canary',
      );
    },
  );

  testWidgets('displays 409 conflict banner and auto-refreshes inbox', (
    tester,
  ) async {
    configureDesktop(tester);
    final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
    addTearDown(repo.dispose);

    repo.onAnswerPause = (_, _) async =>
        const FailureResult(ConflictFailure('Already resolved'));

    await pumpPausesPage(tester, repo);
    await tester.pumpAndSettle();
    final beforeCalls = repo.listCallCount;

    await tester.tap(find.byKey(const Key('pauses_approve_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pauses_conflict_banner')), findsOneWidget);
    expect(
      find.text('This pause was already resolved or cancelled.'),
      findsOneWidget,
    );
    expect(repo.listCallCount, greaterThan(beforeCalls));
  });

  testWidgets('periodic timer refreshes waiting-time labels', (tester) async {
    configureDesktop(tester);
    final createdAt = DateTime.utc(2026, 11, 21, 10);
    var currentNow = DateTime.utc(2026, 11, 21, 10);
    _FakePeriodicTimer? timer;

    final repo = FakePauseRepository(
      initial: <Pause>[makeApproval(createdAt: createdAt)],
    );
    addTearDown(repo.dispose);

    await pumpPausesPage(
      tester,
      repo,
      clockConfig: PausesClockConfig(
        now: () => currentNow,
        createPeriodicTimer: (_, callback) =>
            timer = _FakePeriodicTimer(callback),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Just now'), findsWidgets);

    currentNow = DateTime.utc(2026, 11, 21, 10, 5);
    timer!.fire();
    await tester.pumpAndSettle();

    expect(find.text('5m ago'), findsWidgets);
  });

  testWidgets(
    'exposes selected semantics, keeps drafts, and notices remote resolution',
    (tester) async {
      configureDesktop(tester);
      final approval = makeApproval();
      final question = makeQuestion();
      final repo = FakePauseRepository(initial: <Pause>[approval, question]);
      addTearDown(repo.dispose);

      await pumpPausesPage(tester, repo);
      await tester.pumpAndSettle();

      final approvalSemantics = tester.getSemantics(
        find.byKey(const Key('pause_list_item_pause-approval')),
      );
      final questionSemantics = tester.getSemantics(
        find.byKey(const Key('pause_list_item_pause-question')),
      );
      expect(
        approvalSemantics.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        questionSemantics.getSemanticsData().flagsCollection.isSelected,
        Tristate.isFalse,
      );

      // Enter draft feedback on approval pause, switch to question pause, enter
      // draft answer, and switch back: both drafts are preserved.
      await tester.enterText(
        find.byKey(const Key('pauses_feedback_field')),
        'Hold until metrics settle',
      );
      await tester.tap(find.byKey(const Key('pause_list_item_pause-question')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('pauses_answer_field')),
        'Blue-Green migration',
      );
      await tester.tap(find.byKey(const Key('pause_list_item_pause-approval')));
      await tester.pumpAndSettle();

      expect(find.text('Hold until metrics settle'), findsOneWidget);

      // Remote resolution of currently selected pause shows notice banner and
      // switches to the remaining pause with its preserved draft intact.
      repo.emitResolved(approval.copyWith(status: PauseStatus.answered));
      await tester.pump();
      await tester.pump();

      final liveRegion = tester.widget<Semantics>(
        find.byKey(const Key('pauses_live_region')),
      );
      expect(liveRegion.properties.label, 'Pause resolved: Manual Gate');

      await tester.pumpAndSettle();
      final clearedLiveRegion = tester.widget<Semantics>(
        find.byKey(const Key('pauses_live_region')),
      );
      expect(clearedLiveRegion.properties.label, isEmpty);

      // Identical consecutive announcement fires again after clearing.
      repo.emitCreated(approval.copyWith(id: 'pause-approval-dup'));
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('pauses_live_region')))
            .properties
            .label,
        'New pause waiting: Manual Gate',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('pauses_live_region')))
            .properties
            .label,
        isEmpty,
      );

      expect(
        find.byKey(const Key('pauses_remote_resolved_banner')),
        findsOneWidget,
      );
      expect(
        find.text('Pause "Manual Gate" was resolved or cancelled externally.'),
        findsOneWidget,
      );
      expect(find.text('Blue-Green migration'), findsOneWidget);
    },
  );
}
