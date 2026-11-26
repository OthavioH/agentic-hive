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
        {
          'nodeId': 'gate',
          'kind': 'humanApproval',
          'question': 'Please review.',
        },
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
            kind: PauseKind.humanApproval,
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

      // g2 was not executed again while it waited for its own decision.
      expect(h.approvalPort.requests, 2);

      final done = await h.engine.resume(
        runId,
        input: const ApprovalDecisionInput(
          decision: HumanApprovalDecision.approved,
        ),
      );
      expect(done.valueOrNull?.status, RunStatus.succeeded);
      expect(h.approvalPort.requests, 2);
    });
  });

  group('GraphEngine ask_human live pause (ADR 0019)', () {
    Workflow askFlow() => buildWorkflow(
      nodeIds: ['plan', 'ask', 'build'],
      edges: [
        edge('plan', NodeOutput.onSuccess, 'ask'),
        edge('ask', NodeOutput.onSuccess, 'build'),
      ],
    );

    String pendingPauseId() => h.gateway.pendingForRun(runId).single.pauseId;

    test('pauses the run while the harness stays alive', () async {
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());

      final started = h.engine.start(runId);
      await h.settle();

      expect(h.run.status, RunStatus.paused);
      expect(h.engine.isExecuting(runId), isTrue);
      // The engine never terminates the harness for ask_human.
      expect(h.killer.kills, isEmpty);
      expect(h.gateway.pendingForRun(runId), hasLength(1));
      expect(h.checkpoints.checkpoints.last.pendingNodeIds, ['ask']);
      final paused = h.events.ofType(runId, RunEventType.runPaused).single;
      final node = (paused.payload['pausedNodes']! as List).single as Map;
      expect(node['nodeId'], 'ask');
      expect(node['kind'], 'askHuman');
      expect(node['question'], 'Which database?');
      expect(node['live'], isTrue);
      expect(node['pauseId'], pendingPauseId());
      expect(h.script.runsOf('build'), 0);
      expect(h.events.ofType(runId, RunEventType.nodeFailed), isEmpty);

      h.gateway.submitAnswer(pauseId: pendingPauseId(), answer: 'x');
      await started;
    });

    test('the live answer resumes the same harness without a re-run', () async {
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());
      final started = h.engine.start(runId);
      await h.settle();

      h.gateway.submitAnswer(pauseId: pendingPauseId(), answer: 'PostgreSQL');
      final result = await started;

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.runsOf('ask'), 1);
      expect(h.script.executions.every((c) => c.humanAnswer == null), isTrue);
      expect(h.snapshots.restored, isEmpty);
      expect(h.killer.kills, isEmpty);
      expect(h.runs.statusHistory, [
        RunStatus.paused,
        RunStatus.running,
        RunStatus.succeeded,
      ]);
      final resumed = h.events.ofType(runId, RunEventType.runResumed).single;
      expect(resumed.payload['live'], isTrue);
      final outputs = h.checkpoints.checkpoints.last.nodeOutputs;
      expect((outputs['ask']!['data']! as Map)['answer'], 'PostgreSQL');
    });

    test('holds new work back while a harness waits for a human', () async {
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(
        buildWorkflow(
          nodeIds: ['a', 'ask', 'side', 'sideNext'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'ask'),
            edge('a', NodeOutput.onSuccess, 'side'),
            edge('side', NodeOutput.onSuccess, 'sideNext'),
          ],
        ),
      );

      final started = h.engine.start(runId);
      await h.settle();

      expect(h.run.status, RunStatus.paused);
      expect(h.script.runsOf('side'), 1);
      expect(h.script.runsOf('sideNext'), 0);

      h.gateway.submitAnswer(pauseId: pendingPauseId(), answer: 'x');
      final result = await started;

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.runsOf('sideNext'), 1);
    });

    test('cancelling a live pause kills the harness and releases it', () async {
      h.killer.onKill = (runId, nodeId) => h.gateway.cancelRun(runId);
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());
      final started = h.engine.start(runId);
      await h.settle();

      final cancelled = await h.engine.cancel(runId);

      expect(cancelled.valueOrNull?.status, RunStatus.cancelled);
      expect((await started).valueOrNull?.status, RunStatus.cancelled);
      expect(h.killer.kills, [(runId, null)]);
      expect(h.gateway.allPending, isEmpty);
      expect(h.eventTypes.last, RunEventType.runCancelled);
    });

    test('a live pause keeps the run claimed against resume', () async {
      h.script.on('ask', [askHuman(h, 'Which database?')]);
      await h.createRun(askFlow());
      final started = h.engine.start(runId);
      await h.settle();

      final resume = await h.engine.resume(
        runId,
        input: const HumanAnswerInput(answer: 'PostgreSQL'),
      );

      expect(resume.failureOrNull, isA<ConflictFailure>());
      h.gateway.submitAnswer(pauseId: pendingPauseId(), answer: 'x');
      await started;
    });
  });

  group('GraphEngine ask_human after a restart (ADR 0019)', () {
    Workflow askFlow() => buildWorkflow(
      nodeIds: ['plan', 'ask', 'side', 'build'],
      edges: [
        edge('plan', NodeOutput.onSuccess, 'ask'),
        edge('ask', NodeOutput.onSuccess, 'build'),
      ],
    );

    /// A run left `paused` by a previous backend process: the harness and its
    /// gateway request are gone, only the checkpoint and the pause event
    /// remain. When [siblingCompletedAfter] a parallel node finished after the
    /// asker's snapshot.
    Future<void> seedPausedAsk({bool siblingCompletedAfter = false}) async {
      await h.createRun(askFlow(), status: RunStatus.paused);
      await h.snapshots.captureSnapshot(
        runId: runId,
        workspaceDir: '/workspace',
        nodeId: 'plan',
      );
      await h.checkpoints.append(
        id: 'cp-plan',
        runId: runId,
        pendingNodeIds: ['ask'],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {},
        createdAt: h.tick(),
        completedNodeId: 'plan',
      );
      await h.snapshots.captureSnapshot(
        runId: runId,
        workspaceDir: '/workspace',
        nodeId: 'ask',
      );
      if (siblingCompletedAfter) {
        await h.checkpoints.append(
          id: 'cp-side',
          runId: runId,
          pendingNodeIds: ['ask'],
          attemptsByEdge: const {},
          circuitBreakerCount: 0,
          nodeOutputs: const {},
          createdAt: h.tick(),
          completedNodeId: 'side',
        );
      }
      await h.checkpoints.append(
        id: 'cp-pause',
        runId: runId,
        pendingNodeIds: ['ask'],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {},
        createdAt: h.tick(),
      );
      await h.events.append(
        id: 'ev-paused',
        runId: runId,
        type: RunEventType.runPaused,
        createdAt: h.tick(),
        payload: {
          'pausedNodes': [
            {
              'nodeId': 'ask',
              'kind': 'askHuman',
              'question': 'Which database?',
              'live': true,
            },
          ],
        },
      );
    }

    test('re-runs the node with humanAnswer after a rollback', () async {
      await seedPausedAsk();
      final askSnapshot = h.snapshots.snapshots.last;
      h.script.on('ask', [askHuman(h, 'Which database?')]);

      final result = await h.engine.resume(
        runId,
        input: const HumanAnswerInput(answer: 'PostgreSQL'),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.snapshots.restored, [askSnapshot.id]);
      expect(h.script.runsOf('ask'), 1);
      expect(h.script.executions.first.humanAnswer, 'PostgreSQL');
      expect(h.killer.kills, isEmpty);
      final outputs = h.checkpoints.checkpoints.last.nodeOutputs;
      expect((outputs['ask']!['data']! as Map)['answer'], 'PostgreSQL');
    });

    test(
      'skips the rollback when a sibling completed after the snapshot',
      () async {
        await seedPausedAsk(siblingCompletedAfter: true);
        h.script.on('ask', [askHuman(h, 'Which database?')]);

        final result = await h.engine.resume(
          runId,
          input: const HumanAnswerInput(answer: 'PostgreSQL'),
        );

        expect(result.valueOrNull?.status, RunStatus.succeeded);
        expect(h.snapshots.restored, isEmpty);
        final warning = h.events
            .ofType(runId, RunEventType.snapshotWarning)
            .where((e) => e.payload['reason'] == 'rollback_skipped');
        expect(warning, hasLength(1));
        expect(warning.single.payload['nodeIds'], ['ask']);
        expect(h.script.executions.first.humanAnswer, 'PostgreSQL');
      },
    );

    test('rejects a blank answer and an approval decision', () async {
      await seedPausedAsk();

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

    test('keeps the run paused when the rollback fails', () async {
      await seedPausedAsk();
      h.snapshots.restoreFailure = const NodeExecutionFailure('git failed');

      final result = await h.engine.resume(
        runId,
        input: const HumanAnswerInput(answer: 'PostgreSQL'),
      );

      expect(result.isFailure, isTrue);
      expect(h.run.status, RunStatus.paused);
      expect(h.script.runsOf('ask'), 0);
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

    test(
      'accepts legacy kind:"approval" from F6-F10 checkpoints on resume',
      () async {
        final flow = approvalFlow();
        await h.createRun(flow, status: RunStatus.paused);
        await h.checkpoints.append(
          id: 'cp-legacy',
          runId: runId,
          pendingNodeIds: const ['gate'],
          attemptsByEdge: const {},
          circuitBreakerCount: 0,
          nodeOutputs: const {},
          createdAt: h.tick(),
        );
        await h.events.append(
          id: 'ev-legacy',
          runId: runId,
          type: RunEventType.runPaused,
          createdAt: h.tick(),
          payload: const <String, Object?>{
            'pausedNodes': <Object?>[
              <String, Object?>{
                'nodeId': 'gate',
                'kind': 'approval',
                'question': 'Please review.',
              },
            ],
          },
        );

        final resumed = await h.engine.resume(
          runId,
          input: const ApprovalDecisionInput(
            decision: HumanApprovalDecision.approved,
          ),
        );
        expect(resumed.valueOrNull?.status, RunStatus.succeeded);
      },
    );

    test(
      'fails the run with node.failed and run.failed when persisting a pause '
      'in PauseRepository fails',
      () async {
        h.pauses.createFailure = const PersistenceFailure('PK collision');
        await h.createRun(approvalFlow());

        final result = await h.engine.start(runId);

        expect(result.valueOrNull?.status, RunStatus.failed);
        expect(h.run.status, RunStatus.failed);
        expect(h.events.ofType(runId, RunEventType.nodeFailed), isNotEmpty);
        expect(h.events.ofType(runId, RunEventType.runFailed), hasLength(1));
      },
    );

    test('cancels pending pause and attempt waiter when a live ask_human node '
        'ends unanswered', () async {
      final flow = buildWorkflow(nodeIds: ['ask'], edges: const []);
      await h.createRun(flow);

      final exitGate = Completer<void>();
      h.script.on('ask', [
        (context) async {
          unawaited(
            h.gateway.requestHumanAnswer(
              runId: context.runId,
              nodeId: context.nodeId,
              attempt: context.attempt,
              question: 'Still there?',
            ),
          );
          await exitGate.future;
          return const FailureResult(NodeExecutionFailure('timed out'));
        },
        (_) async => const Success(NodeOutcome(outputLabel: 'onSuccess')),
      ]);

      final runFuture = h.engine.start(runId);
      await h.settle();

      expect(h.run.status, RunStatus.paused);
      final pendingBefore = (await h.pauses.listPendingForRun(runId))
          .valueOrNull!;
      expect(pendingBefore, hasLength(1));
      final pauseId = pendingBefore.single.id;

      // Node exits with timeout failure without waiting for the human answer.
      exitGate.complete();
      final finished = await runFuture;

      expect(finished.valueOrNull?.status, RunStatus.succeeded);
      expect(h.gateway.pendingForRun(runId), isEmpty);
      final pauseAfter = (await h.pauses.getById(pauseId)).valueOrNull!;
      expect(pauseAfter.status, PauseStatus.cancelled);
    });

    test('beginPausedResume accepts back-to-back answers for two concurrent '
        'approvals without losing the second answer', () async {
      final flow = buildWorkflow(
        nodeIds: ['start', 'g1', 'g2'],
        approvals: {'g1', 'g2'},
        edges: [
          edge('start', 'onSuccess', 'g1'),
          edge('start', 'onSuccess', 'g2'),
        ],
      );
      await h.createRun(flow);
      final paused = await h.engine.start(runId);
      expect(paused.valueOrNull?.status, RunStatus.paused);

      final first = await h.engine.beginPausedResume(
        runId,
        input: const ApprovalDecisionInput(
          nodeId: 'g1',
          decision: HumanApprovalDecision.approved,
        ),
      );
      final second = await h.engine.beginPausedResume(
        runId,
        input: const ApprovalDecisionInput(
          nodeId: 'g2',
          decision: HumanApprovalDecision.approved,
        ),
      );

      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);

      final settled = await second.valueOrNull!.done;
      expect(settled.valueOrNull?.status, RunStatus.succeeded);
    });

    test('beginPausedResume accepts back-to-back answers for two post-restart '
        'ask_human pauses and runs both with their humanAnswers', () async {
      final flow = buildWorkflow(
        nodeIds: ['start', 'ask1', 'ask2'],
        edges: [
          edge('start', 'onSuccess', 'ask1'),
          edge('start', 'onSuccess', 'ask2'),
        ],
      );
      await h.createRun(flow, status: RunStatus.paused);
      await h.checkpoints.append(
        id: 'cp-1',
        runId: runId,
        completedNodeId: 'start',
        pendingNodeIds: const ['ask1', 'ask2'],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {
          'start': {'outputLabel': 'onSuccess', 'data': <String, Object?>{}},
        },
        createdAt: h.tick(),
      );
      await h.events.append(
        id: 'ev-paused',
        runId: runId,
        type: RunEventType.runPaused,
        createdAt: h.tick(),
        payload: const <String, Object?>{
          'pausedNodes': <Object?>[
            <String, Object?>{
              'nodeId': 'ask1',
              'kind': 'askHuman',
              'question': 'Q1?',
            },
            <String, Object?>{
              'nodeId': 'ask2',
              'kind': 'askHuman',
              'question': 'Q2?',
            },
          ],
        },
      );

      final first = await h.engine.beginPausedResume(
        runId,
        input: const HumanAnswerInput(nodeId: 'ask1', answer: 'A1'),
      );
      final second = await h.engine.beginPausedResume(
        runId,
        input: const HumanAnswerInput(nodeId: 'ask2', answer: 'A2'),
      );

      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);

      final settled = await second.valueOrNull!.done;
      expect(settled.valueOrNull?.status, RunStatus.succeeded);
      final answersByNode = <String, String?>{
        for (final exec in h.script.executions) exec.nodeId: exec.humanAnswer,
      };
      expect(answersByNode['ask1'], 'A1');
      expect(answersByNode['ask2'], 'A2');
    });
  });

  group('Pause parentRunId linkage', () {
    test('a pause in a child run carries the parent run id', () async {
      final wf = Workflow(
        id: 'wf-child',
        name: 'Child Flow',
        nodes: const [
          WorkflowNode(
            id: 'gate',
            type: 'human_approval',
            label: 'Approve',
            position: WorkflowPosition(x: 0, y: 0),
            config: {'instructions': 'Please approve'},
          ),
        ],
        edges: const [],
        entryNodeId: 'gate',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await h.runs.create(
        Run(
          id: 'child-1',
          workflowId: wf.id,
          workflowName: wf.name,
          workflowDefinition: wf,
          workspaceRoot: '.',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
          parentRunId: 'parent-1',
        ),
      );

      final startFuture = h.engine.start('child-1');
      await h.settle();
      while (h.pauses.pauses.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(h.pauses.pauses.values.single.parentRunId, 'parent-1');

      await h.engine.cancel('child-1');
      await startFuture;
    });

    test('a pause in an ordinary run has no parent run id', () async {
      final wf = Workflow(
        id: 'wf-plain',
        name: 'Plain Flow',
        nodes: const [
          WorkflowNode(
            id: 'gate',
            type: 'human_approval',
            label: 'Approve',
            position: WorkflowPosition(x: 0, y: 0),
            config: {'instructions': 'Please approve'},
          ),
        ],
        edges: const [],
        entryNodeId: 'gate',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await h.runs.create(
        Run(
          id: 'plain-1',
          workflowId: wf.id,
          workflowName: wf.name,
          workflowDefinition: wf,
          workspaceRoot: '.',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );

      final startFuture = h.engine.start('plain-1');
      await h.settle();

      expect(h.pauses.pauses.values.single.parentRunId, isNull);

      await h.engine.cancel('plain-1');
      await startFuture;
    });
  });
}
