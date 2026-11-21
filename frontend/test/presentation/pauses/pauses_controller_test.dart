import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_controller.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_state.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pending_pauses_count_provider.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_pause_repository.dart';

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

  test('submitApproval sends decision and removes resolved pause', () async {
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
    final state = container.read(pausesControllerProvider);
    expect(state.pauses.requireValue, isEmpty);
    expect(state.lastAnnouncement, isA<PauseResolvedAnnouncement>());
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
}
