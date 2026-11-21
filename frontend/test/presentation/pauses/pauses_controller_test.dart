import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_controller.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_state.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pending_pauses_count_provider.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Pause makeApproval({String id = 'pause-1', DateTime? createdAt}) => Pause(
    id: id,
    runId: 'run-1',
    nodeId: 'node-1',
    kind: PauseKind.humanApproval,
    status: PauseStatus.pending,
    workflowName: 'Deploy Pipeline',
    nodeLabel: 'Approve Production',
    createdAt: createdAt ?? DateTime.utc(2026, 11, 21, 10),
    title: 'Deploy to prod?',
    instructions: 'Check staging metrics first.',
  );

  Pause makeQuestion({String id = 'pause-2', DateTime? createdAt}) => Pause(
    id: id,
    runId: 'run-2',
    nodeId: 'node-2',
    kind: PauseKind.askHuman,
    status: PauseStatus.pending,
    workflowName: 'Refactor Auth',
    nodeLabel: 'Clarify Scope',
    createdAt: createdAt ?? DateTime.utc(2026, 11, 21, 11),
    question: 'Which OAuth provider should we target?',
    options: const <String>['GitHub', 'Google'],
  );

  test('pendingPausesCountProvider updates on created and resolved', () async {
    final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
    addTearDown(repo.dispose);

    final container = ProviderContainer.test(
      overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
    );

    final counts = <int>[];
    final sub = container.listen(pendingPausesCountProvider, (_, next) {
      if (next case AsyncData<int>(:final value)) {
        counts.add(value);
      }
    }, fireImmediately: true);
    addTearDown(sub.close);

    await Future<void>.delayed(Duration.zero);
    expect(counts.last, 1);

    repo.emitCreated(makeQuestion());
    await Future<void>.delayed(Duration.zero);
    expect(counts.last, 2);

    repo.emitResolved(makeApproval().copyWith(status: PauseStatus.answered));
    await Future<void>.delayed(Duration.zero);
    expect(counts.last, 1);
  });

  test('PausesController loads sorted pauses and selects first', () async {
    final newer = makeQuestion(createdAt: DateTime.utc(2026, 11, 21, 12));
    final older = makeApproval(createdAt: DateTime.utc(2026, 11, 21, 9));
    final repo = FakePauseRepository(initial: <Pause>[newer, older]);
    addTearDown(repo.dispose);

    final container = ProviderContainer.test(
      overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
    );

    final sub = container.listen(pausesControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(pausesControllerProvider);
    final items = state.pauses.requireValue;
    expect(items.map((p) => p.id), <String>['pause-1', 'pause-2']);
    expect(state.selectedPauseId, 'pause-1');
  });

  test('submitApproval sends decision without announcing own submit', () async {
    final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
    addTearDown(repo.dispose);

    final container = ProviderContainer.test(
      overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
    );

    final sub = container.listen(pausesControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    final ok = await container
        .read(pausesControllerProvider.notifier)
        .submitApproval(
          pauseId: 'pause-1',
          approved: true,
          feedback: '  Looks good  ',
        );

    expect(ok, isTrue);
    expect(repo.recordedAnswers.single.id, 'pause-1');
    expect(repo.recordedAnswers.single.request.decision, 'approved');
    expect(repo.recordedAnswers.single.request.feedback, 'Looks good');
    var state = container.read(pausesControllerProvider);
    expect(state.pauses.requireValue, isEmpty);
    expect(state.lastAnnouncement, isNull);

    // Even if the backend broadcasts pause.resolved for the user's own submit,
    // it must not announce or show the remote-resolved banner.
    repo.emitResolved(makeApproval().copyWith(status: PauseStatus.answered));
    await Future<void>.delayed(Duration.zero);
    state = container.read(pausesControllerProvider);
    expect(state.lastAnnouncement, isNull);
    expect(state.remoteResolvedNodeLabel, isNull);
  });

  test('409 conflict sets hasConflict and auto-refreshes inbox', () async {
    final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
    addTearDown(repo.dispose);

    repo.onAnswerPause = (_, _) async => const FailureResult(
      BackendFailure(
        'Pause already answered',
        code: ApiErrorCode.conflict,
        statusCode: 409,
      ),
    );

    final container = ProviderContainer.test(
      overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
    );

    final sub = container.listen(pausesControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    final initialCalls = repo.listCallCount;

    final ok = await container
        .read(pausesControllerProvider.notifier)
        .submitApproval(pauseId: 'pause-1', approved: false);

    expect(ok, isFalse);
    final state = container.read(pausesControllerProvider);
    expect(state.hasConflict, isTrue);
    expect(repo.listCallCount, greaterThan(initialCalls));
  });

  test(
    'merges pause.created arriving while loadPauses fetch is in flight',
    () async {
      final repo = FakePauseRepository();
      addTearDown(repo.dispose);

      final fetchCompleter = Completer<Result<List<Pause>>>();
      repo.onListPendingPauses = () => fetchCompleter.future;

      final container = ProviderContainer.test(
        overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
      );

      final sub = container.listen(pausesControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      repo.emitCreated(makeQuestion());
      await Future<void>.delayed(Duration.zero);

      fetchCompleter.complete(Success(<Pause>[makeApproval()]));
      await Future<void>.delayed(Duration.zero);

      final items = container
          .read(pausesControllerProvider)
          .pauses
          .requireValue;
      expect(items.map((p) => p.id), <String>['pause-1', 'pause-2']);
    },
  );

  test('silent refresh failure keeps previous data', () async {
    final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
    addTearDown(repo.dispose);

    final container = ProviderContainer.test(
      overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
    );

    final sub = container.listen(pausesControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(pausesControllerProvider).pauses.requireValue,
      hasLength(1),
    );

    repo.onListPendingPauses = () async =>
        const FailureResult(NetworkFailure('Reconnect failed'));

    await container
        .read(pausesControllerProvider.notifier)
        .loadPauses(showLoading: false);

    final state = container.read(pausesControllerProvider);
    expect(state.pauses.hasValue, isTrue);
    expect(state.pauses.requireValue.single.id, 'pause-1');
  });

  test(
    'periodic clock timer updates state.now and cancels on dispose',
    () async {
      final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
      addTearDown(repo.dispose);

      var currentNow = DateTime.utc(2026, 11, 21, 10);
      _FakePeriodicTimer? capturedTimer;

      final container = ProviderContainer.test(
        overrides: [
          pauseRepositoryProvider.overrideWithValue(repo),
          pausesClockConfigProvider.overrideWithValue(
            PausesClockConfig(
              now: () => currentNow,
              createPeriodicTimer: (_, callback) {
                return capturedTimer = _FakePeriodicTimer(callback);
              },
            ),
          ),
        ],
      );

      final sub = container.listen(pausesControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(container.read(pausesControllerProvider).now, currentNow);
      expect(capturedTimer, isNotNull);
      expect(capturedTimer!.isActive, isTrue);

      currentNow = DateTime.utc(2026, 11, 21, 10, 5);
      capturedTimer!.fire();
      expect(container.read(pausesControllerProvider).now, currentNow);

      sub.close();
      container.dispose();
      expect(capturedTimer!.isActive, isFalse);
    },
  );

  test(
    'preserves drafts across selection and notices remote resolve',
    () async {
      final repo = FakePauseRepository(
        initial: <Pause>[makeApproval(), makeQuestion()],
      );
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
      );

      final sub = container.listen(pausesControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(pausesControllerProvider.notifier)
        ..updateFeedbackDraft('pause-1', 'Draft feedback 1')
        ..selectPause('pause-2')
        ..updateAnswerDraft('pause-2', 'Draft answer 2')
        ..selectPause('pause-1');

      var state = container.read(pausesControllerProvider);
      expect(state.feedbackDraftFor('pause-1'), 'Draft feedback 1');
      expect(state.answerDraftFor('pause-2'), 'Draft answer 2');

      repo.emitResolved(makeApproval().copyWith(status: PauseStatus.answered));
      await Future<void>.delayed(Duration.zero);

      state = container.read(pausesControllerProvider);
      expect(state.selectedPauseId, 'pause-2');
      expect(state.remoteResolvedNodeLabel, 'Approve Production');
      expect(state.lastAnnouncement, isA<PauseResolvedAnnouncement>());
      expect(state.feedbackDraftFor('pause-1'), isEmpty);
      expect(state.answerDraftFor('pause-2'), 'Draft answer 2');

      notifier.clearAnnouncement();
      expect(container.read(pausesControllerProvider).lastAnnouncement, isNull);
    },
  );
}
