import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';
import 'support/fake_ports.dart';

void main() {
  Future<Result<Run>> startRun(EngineHarness h, Workflow workflow) async {
    await h.createRun(workflow);
    return await h.engine.start(runId);
  }

  /// `coder -> tests`, with `tests --onFailure--> coder` limited to [max].
  Workflow retryLoop({required int max}) => buildWorkflow(
    nodeIds: ['coder', 'tests', 'done'],
    edges: [
      edge('coder', NodeOutput.onSuccess, 'tests'),
      edge('tests', NodeOutput.onFailure, 'coder', maxRetries: max),
      edge('tests', NodeOutput.onSuccess, 'done'),
    ],
  );

  group('GraphEngine cycle retries', () {
    test(
      'tracks attemptsByEdge and emits node.retried per traversal',
      () async {
        final h = EngineHarness();
        h.script.on('tests', [
          outcome(NodeOutput.onFailure),
          outcome(NodeOutput.onFailure),
          outcome(NodeOutput.onSuccess),
        ]);

        final result = await startRun(h, retryLoop(max: 3));

        expect(result.valueOrNull?.status, RunStatus.succeeded);
        expect(h.script.runsOf('coder'), 3);
        expect(h.checkpoints.checkpoints.last.attemptsByEdge, {
          'tests-onFailure-coder': 2,
        });
        final retried = h.events.ofType(runId, RunEventType.nodeRetried);
        expect(retried, hasLength(2));
        expect(retried.first.edgeId, 'tests-onFailure-coder');
        expect(retried.first.nodeId, 'coder');
        expect(retried.map((e) => e.payload['attempt']), [1, 2]);
      },
    );

    test('fails the run once the edge reaches maxRetries', () async {
      final h = EngineHarness();
      h.script.on('tests', [outcome(NodeOutput.onFailure)]);

      final result = await startRun(h, retryLoop(max: 2));

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.script.runsOf('coder'), 3);
      expect(h.script.runsOf('tests'), 3);
      expect(h.events.ofType(runId, RunEventType.nodeRetried), hasLength(2));
      expect(h.run.errorMessage, contains('tests-onFailure-coder'));
      expect(h.run.errorMessage, contains('2'));
    });

    test('does not roll the workspace back between attempts', () async {
      final h = EngineHarness();
      h.script.on('tests', [
        outcome(NodeOutput.onFailure),
        outcome(NodeOutput.onSuccess),
      ]);

      await startRun(h, retryLoop(max: 3));

      expect(h.snapshots.restored, isEmpty);
      expect(h.eventTypes, isNot(contains(RunEventType.snapshotRestored)));
    });

    test('maxRetries 0 blocks the first traversal', () async {
      final h = EngineHarness();
      h.script.on('tests', [outcome(NodeOutput.onFailure)]);

      final result = await startRun(h, retryLoop(max: 0));

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.script.runsOf('coder'), 1);
      expect(h.events.ofType(runId, RunEventType.nodeRetried), isEmpty);
    });
  });

  group('GraphEngine circuit breaker', () {
    Workflow single() => buildWorkflow(
      nodeIds: ['a', 'b'],
      edges: [edge('a', NodeOutput.onSuccess, 'b')],
    );

    test('trips after 3 consecutive infrastructure failures', () async {
      final h = EngineHarness();
      h.script.on('a', [infraFailure()]);

      final result = await startRun(h, single());

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.script.runsOf('a'), 3);
      expect(h.run.errorMessage, contains('Circuit breaker'));
      expect(h.events.ofType(runId, RunEventType.nodeFailed), hasLength(3));
    });

    test('the threshold is configurable', () async {
      final h = EngineHarness(circuitBreakerThreshold: 2);
      h.script.on('a', [infraFailure()]);

      await startRun(h, single());

      expect(h.script.runsOf('a'), 2);
      expect(h.run.status, RunStatus.failed);
    });

    test('a normal outcome resets the counter', () async {
      final h = EngineHarness();
      h.script
        ..on('a', [
          infraFailure(),
          infraFailure(),
          outcome(NodeOutput.onSuccess),
        ])
        ..on('b', [
          infraFailure(),
          infraFailure(),
          outcome(NodeOutput.onSuccess),
        ]);

      final result = await startRun(h, single());

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.runsOf('a'), 3);
      expect(h.script.runsOf('b'), 3);
      expect(h.checkpoints.checkpoints.last.circuitBreakerCount, 0);
    });

    test('onFailure outcomes never trip the breaker', () async {
      final h = EngineHarness();
      h.script.on('tests', [
        for (var i = 0; i < 5; i++) outcome(NodeOutput.onFailure),
        outcome(NodeOutput.onSuccess),
      ]);

      final result = await startRun(h, retryLoop(max: 10));

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(
        h.checkpoints.checkpoints.map((c) => c.circuitBreakerCount),
        everyElement(0),
      );
    });

    test('rejected and changesRequested outcomes reset the counter', () async {
      final h = EngineHarness();
      h.script.on('review', [
        infraFailure(),
        infraFailure(),
        outcome(NodeOutput.changesRequested),
        infraFailure(),
        infraFailure(),
        outcome(NodeOutput.approved),
      ]);

      final result = await startRun(
        h,
        buildWorkflow(
          nodeIds: ['review', 'rework', 'ship'],
          edges: [
            edge('review', NodeOutput.approved, 'ship'),
            edge('review', NodeOutput.changesRequested, 'rework'),
            edge('rework', NodeOutput.onSuccess, 'review', maxRetries: 3),
          ],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.runsOf('review'), 6);
    });

    test('retries an infrastructure failure on the same node', () async {
      final h = EngineHarness();
      h.script.on('a', [infraFailure(), outcome(NodeOutput.onSuccess)]);

      final result = await startRun(h, single());

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.startOrder, ['a', 'a', 'b']);
      expect(h.script.executions[1].attempt, 2);
    });

    test('an authentication failure fails the run without retrying', () async {
      final h = EngineHarness();
      h.script.on('a', [
        (_) async => const FailureResult(
          HarnessAuthenticationFailure(
            'Sign in to Claude Code.',
            harnessType: 'harness.claude_code',
          ),
        ),
      ]);

      final result = await startRun(h, single());

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.script.runsOf('a'), 1);
      expect(h.run.errorMessage, contains('Sign in'));
    });

    test('a node that throws fails the run instead of hanging', () async {
      final h = EngineHarness();
      h.script.on('a', [(_) async => throw StateError('boom')]);

      final result = await startRun(h, single());

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.run.errorMessage, contains('boom'));
    });
  });
}
