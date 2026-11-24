import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_pause_repository.dart';

void main() {
  Pause makeApproval({
    String id = 'pause-1',
    DateTime? createdAt,
    Object? proposal = const <String, Object?>{'step': 1},
  }) => Pause(
    id: id,
    runId: 'run-1',
    nodeId: 'node-1',
    kind: PauseKind.humanApproval,
    status: PauseStatus.pending,
    workflowName: 'Deploy Pipeline',
    nodeLabel: 'Approve Plan',
    createdAt: createdAt ?? DateTime.utc(2026, 11, 21, 10),
    title: 'Approve proposal?',
    instructions: 'Review the proposal JSON.',
    proposal: proposal,
    proposalSource: 'planner',
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

  test('R9: manages proposal drafts across edit, update, discard, and '
      'pause selection', () async {
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
      ..startProposalEdit('pause-1', '{"step": 1}');

    var state = container.read(pausesControllerProvider);
    expect(state.isEditingProposal('pause-1'), isTrue);
    expect(state.proposalDraftFor('pause-1'), '{"step": 1}');

    // startProposalEdit is a no-op if already editing.
    notifier
      ..startProposalEdit('pause-1', '{"step": 999}')
      ..updateProposalDraft('pause-1', '{"step": 2}')
      ..selectPause('pause-2')
      ..selectPause('pause-1');

    state = container.read(pausesControllerProvider);
    expect(state.isEditingProposal('pause-1'), isTrue);
    expect(state.proposalDraftFor('pause-1'), '{"step": 2}');

    notifier.discardProposalEdit('pause-1');
    state = container.read(pausesControllerProvider);
    expect(state.isEditingProposal('pause-1'), isFalse);
    expect(state.proposalDraftFor('pause-1'), isNull);
  });

  test('R9: successful submitApproval removes proposal draft', () async {
    final repo = FakePauseRepository(initial: <Pause>[makeApproval()]);
    addTearDown(repo.dispose);

    final container = ProviderContainer.test(
      overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = container.listen(pausesControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(pausesControllerProvider.notifier)
      ..startProposalEdit('pause-1', '{"step": 2}');

    final ok = await notifier.submitApproval(
      pauseId: 'pause-1',
      approved: true,
      proposal: const <String, Object?>{'step': 2},
    );

    expect(ok, isTrue);
    final state = container.read(pausesControllerProvider);
    expect(state.isEditingProposal('pause-1'), isFalse);
    expect(state.proposalDraftFor('pause-1'), isNull);
  });

  test('R9: PauseResolvedEvent removes proposal draft', () async {
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

    container
        .read(pausesControllerProvider.notifier)
        .startProposalEdit('pause-1', '{"step": 2}');
    expect(
      container.read(pausesControllerProvider).isEditingProposal('pause-1'),
      isTrue,
    );

    repo.emitResolved(makeApproval().copyWith(status: PauseStatus.answered));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(pausesControllerProvider);
    expect(state.isEditingProposal('pause-1'), isFalse);
    expect(state.proposalDraftFor('pause-1'), isNull);
  });

  test(
    'R6: submitApproval with approved=false strips proposal from request',
    () async {
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
            approved: false,
            feedback: 'Needs work',
            proposal: const <String, Object?>{'step': 2},
          );

      expect(ok, isTrue);
      expect(repo.recordedAnswers.single.request.decision, 'rejected');
      expect(repo.recordedAnswers.single.request.feedback, 'Needs work');
      expect(repo.recordedAnswers.single.request.proposal, isNull);
    },
  );

  test(
    'R5: submitApproval with approved=true sends decoded proposal',
    () async {
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
            proposal: const <int>[1, 2],
          );

      expect(ok, isTrue);
      expect(repo.recordedAnswers.single.request.decision, 'approved');
      expect(repo.recordedAnswers.single.request.proposal, <int>[1, 2]);
    },
  );
}
