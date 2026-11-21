import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';
import 'support/fake_ports.dart';

/// A node that calls `ask_human` like a harness does, and finishes with the
/// answer when it is re-run with `humanAnswer`.
NodeBehavior askHuman(EngineHarness h, String question) => (context) async {
  final answer = context.humanAnswer;
  if (answer != null) {
    return Success(
      NodeOutcome(
        outputLabel: NodeOutput.onSuccess,
        data: <String, Object?>{'answer': answer},
      ),
    );
  }
  final reply = await h.gateway.requestHumanAnswer(
    runId: context.runId,
    nodeId: context.nodeId,
    attempt: context.attempt,
    question: question,
  );
  return reply.map(
    (value) => NodeOutcome(
      outputLabel: NodeOutput.onSuccess,
      data: <String, Object?>{'answer': value},
    ),
  );
};

void main() {
  late EngineHarness h;

  setUp(() => h = EngineHarness());

  Workflow approvalFlow() => buildWorkflow(
    nodeIds: ['work', 'gate', 'ship', 'rework'],
    approvals: {'gate'},
    edges: [
      edge('work', NodeOutput.onSuccess, 'gate'),
      edge('gate', NodeOutput.approved, 'ship'),
      edge('gate', NodeOutput.rejected, 'rework'),
    ],
  );

  group('GraphEngine human approval pause', () {
    test('persists a checkpoint, emits run.paused and leaves memory', () async {
      await h.createRun(approvalFlow());

      final result = await h.engine.start(runId);

      expect(result.valueOrNull?.status, RunStatus.paused);
      expect(h.run.status, RunStatus.paused);
      expect(h.engine.isExecuting(runId), isFalse);
      final latest = h.checkpoints.checkpoints.last;
      expect(latest.pendingNodeIds, ['gate']);
      expect(latest.nodeOutputs.keys, ['work']);
      final paused = h.events.ofType(runId, RunEventType.runPaused).single;
      expect(paused.payload['pausedNodes'], [
        {'nodeId': 'gate', 'kind': 'approval', 'question': 'Please review.'},
      ]);
      expect(h.script.runsOf('ship'), 0);
      // The checkpoint is saved before the run enters `paused`.
      expect(
        h.eventTypes.indexOf(RunEventType.checkpointSaved),
        lessThan(h.eventTypes.indexOf(RunEventType.runPaused)),
      );
    });

    test('resumes straight to approved without re-running the node', () async {
      await h.createRun(approvalFlow());
      await h.engine.start(runId);

      final result = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
          feedback: 'looks good',
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.approvalPort.requests, 1);
      expect(h.script.startOrder, ['work', 'ship']);
      final outputs = h.checkpoints.checkpoints.last.nodeOutputs;
      expect(outputs['gate']!['outputLabel'], NodeOutput.approved);
      expect((outputs['gate']!['data']! as Map)['feedback'], 'looks good');
      expect(h.events.ofType(runId, RunEventType.runResumed), hasLength(1));
    });

    test('resumes to rejected and follows the rejected edge', () async {
      await h.createRun(approvalFlow());
      await h.engine.start(runId);

      await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.rejected,
        ),
      );

      expect(h.script.startOrder, ['work', 'rework']);
      expect(h.run.status, RunStatus.succeeded);
    });

    test('requires a decision and keeps the run paused otherwise', () async {
      await h.createRun(approvalFlow());
      await h.engine.start(runId);

      final missing = await h.engine.resume(runId);
      final wrongKind = await h.engine.resume(
        runId,
        input: const HumanAnswerInput(answer: 'yes'),
      );

      expect(missing.failureOrNull, isA<ValidationFailure>());
      expect(wrongKind.failureOrNull, isA<ValidationFailure>());
      expect(h.run.status, RunStatus.paused);
      expect(h.engine.isExecuting(runId), isFalse);
    });

    test('keeps attemptsByEdge across pause and resume', () async {
      h.script.on('tests', [
        outcome(NodeOutput.onFailure),
        outcome(NodeOutput.onSuccess),
      ]);
      await h.createRun(
        buildWorkflow(
          nodeIds: ['coder', 'tests', 'gate', 'done'],
          approvals: {'gate'},
          edges: [
            edge('coder', NodeOutput.onSuccess, 'tests'),
            edge('tests', NodeOutput.onFailure, 'coder', maxRetries: 3),
            edge('tests', NodeOutput.onSuccess, 'gate'),
            edge('gate', NodeOutput.approved, 'done'),
          ],
        ),
      );

      await h.engine.start(runId);
      expect(h.checkpoints.checkpoints.last.attemptsByEdge, {
        'tests-onFailure-coder': 1,
      });

      await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );

      expect(h.run.status, RunStatus.succeeded);
      expect(h.checkpoints.checkpoints.last.attemptsByEdge, {
        'tests-onFailure-coder': 1,
      });
    });

    test('keeps the circuit breaker count in the pause checkpoint', () async {
      h.script.on('a', [
        infraFailure(),
        (_) async => const FailureResult(
          PauseRequestedFailure(
            'wait',
            kind: PauseKind.approval,
            runId: runId,
            nodeId: 'a',
          ),
        ),
      ]);
      await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));

      await h.engine.start(runId);

      expect(h.run.status, RunStatus.paused);
      expect(h.checkpoints.checkpoints.last.circuitBreakerCount, 1);
    });

    test('a sibling branch keeps running while another one pauses', () async {
      await h.createRun(
        buildWorkflow(
          nodeIds: ['a', 'gate', 'side', 'sideNext'],
          approvals: {'gate'},
          edges: [
            edge('a', NodeOutput.onSuccess, 'gate'),
            edge('a', NodeOutput.onSuccess, 'side'),
            edge('side', NodeOutput.onSuccess, 'sideNext'),
          ],
        ),
      );

      await h.engine.start(runId);

      expect(h.run.status, RunStatus.paused);
      expect(h.script.runsOf('side'), 1);
      // New work is held back while the run waits for the human.
      expect(h.script.runsOf('sideNext'), 0);
      expect(
        h.checkpoints.checkpoints.last.pendingNodeIds,
        unorderedEquals(['gate', 'sideNext']),
      );

      await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );

      expect(h.run.status, RunStatus.succeeded);
      expect(h.script.runsOf('sideNext'), 1);
    });

    test('two paused nodes are resumed one at a time', () async {
      await h.createRun(
        buildWorkflow(
          nodeIds: ['a', 'g1', 'g2'],
          approvals: {'g1', 'g2'},
          edges: [
            edge('a', NodeOutput.onSuccess, 'g1'),
            edge('a', NodeOutput.onSuccess, 'g2'),
          ],
        ),
      );
      await h.engine.start(runId);
      final paused = h.events.ofType(runId, RunEventType.runPaused).single;
      expect((paused.payload['pausedNodes']! as List).length, 2);

      final ambiguous = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );
      expect(ambiguous.failureOrNull, isA<ValidationFailure>());

      final partial = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
          nodeId: 'g1',
        ),
      );
      expect(partial.valueOrNull?.status, RunStatus.paused);

      final done = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );
      expect(done.valueOrNull?.status, RunStatus.succeeded);
    });
  });

  group('GraphEngine ask_human pause', () {
    Workflow askFlow() => buildWorkflow(
      nodeIds: ['plan', 'ask', 'build'],
      edges: [
        edge('plan', NodeOutput.onSuccess, 'ask'),
        edge('ask', NodeOutput.onSuccess, 'build'),
      ],
    );

    test('terminates the harness, then saves the pause checkpoint', () async {
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());

      final result = await h.engine.start(runId);

      expect(result.valueOrNull?.status, RunStatus.paused);
      expect(h.killer.kills, [(runId, 'ask')]);
      expect(h.killer.confirmed, isTrue);
      expect(h.gateway.allPending, isEmpty);
      final latest = h.checkpoints.checkpoints.last;
      expect(latest.pendingNodeIds, ['ask']);
      final paused = h.events.ofType(runId, RunEventType.runPaused).single;
      expect(paused.payload['pausedNodes'], [
        {'nodeId': 'ask', 'kind': 'askHuman', 'question': 'Which database?'},
      ]);
      expect(h.script.runsOf('build'), 0);
      // The harness exit is not an infrastructure failure.
      expect(h.events.ofType(runId, RunEventType.nodeFailed), isEmpty);
    });

    test('waits for the process tree to exit before pausing', () async {
      final exit = Completer<void>();
      h.killer.confirmation = exit.future;
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());

      final started = h.engine.start(runId);
      await h.settle();

      expect(h.killer.kills, isNotEmpty);
      expect(h.run.status, RunStatus.running);
      expect(h.eventTypes, isNot(contains(RunEventType.runPaused)));

      exit.complete();
      expect((await started).valueOrNull?.status, RunStatus.paused);
    });

    test('re-runs the node with humanAnswer after a rollback', () async {
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());
      await h.engine.start(runId);
      final askSnapshot = h.snapshots.snapshots.lastWhere(
        (s) => s.nodeId == 'ask',
      );

      final result = await h.engine.resume(
        runId,
        input: const HumanAnswerInput(answer: 'PostgreSQL'),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.snapshots.restored, [askSnapshot.id]);
      expect(h.script.runsOf('ask'), 2);
      final askRuns = h.script.executions.where((c) => c.nodeId == 'ask');
      expect(askRuns.last.humanAnswer, 'PostgreSQL');
      expect(askRuns.first.humanAnswer, isNull);
      final outputs = h.checkpoints.checkpoints.last.nodeOutputs;
      expect((outputs['ask']!['data']! as Map)['answer'], 'PostgreSQL');
      expect(h.script.startOrder.last, 'build');
    });

    test('rejects a blank answer and an approval decision', () async {
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());
      await h.engine.start(runId);

      final blank = await h.engine.resume(
        runId,
        input: const HumanAnswerInput(answer: '  '),
      );
      final wrongKind = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );

      expect(blank.failureOrNull, isA<ValidationFailure>());
      expect(wrongKind.failureOrNull, isA<ValidationFailure>());
      expect(h.run.status, RunStatus.paused);
      expect(h.snapshots.restored, isEmpty);
    });

    test('fails the run when the harness cannot be terminated', () async {
      h.killer.failure = const NodeExecutionFailure('kill refused');
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());

      final result = await h.engine.start(runId);

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.run.errorMessage, contains('kill refused'));
    });

    test('keeps the run paused when the rollback fails', () async {
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());
      await h.engine.start(runId);
      h.snapshots.restoreFailure = const NodeExecutionFailure('git failed');

      final result = await h.engine.resume(
        runId,
        input: const HumanAnswerInput(answer: 'PostgreSQL'),
      );

      expect(result.isFailure, isTrue);
      expect(h.run.status, RunStatus.paused);
      expect(h.script.runsOf('ask'), 1);
    });
  });

  group('GraphEngine resume guards', () {
    test('rejects resuming a run that is not paused or interrupted', () async {
      await h.createRun(buildWorkflow(nodeIds: ['a'], edges: const []));
      await h.engine.start(runId);

      final result = await h.engine.resume(runId);

      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test('returns NotFoundFailure for an unknown run', () async {
      final result = await h.engine.resume('missing');

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });
}
