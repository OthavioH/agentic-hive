import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';
import 'support/fake_ports.dart';

final class _FakeHarnessNode extends Node {
  const new({
    required this.descriptor,
    required this.script,
    required this.executions,
  });

  @override
  final NodeDescriptor descriptor;

  @override
  String get typeId => descriptor.typeId;

  final NodeScript script;
  final List<(String typeId, NodeExecutionContext context)> executions;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) {
    executions.add((descriptor.typeId, context));
    return script.run(context);
  }
}

NodeBehavior _rateLimit(
  String message, {
  String harness = NodeTypeId.claudeCode,
}) =>
    (_) async =>
        FailureResult(HarnessRateLimitFailure(message, harnessType: harness));

NodeBehavior _authFailure(
  String message, {
  String harness = NodeTypeId.claudeCode,
}) =>
    (_) async => FailureResult(
      HarnessAuthenticationFailure(message, harnessType: harness),
    );

void main() {
  late EngineHarness h;
  late List<(String typeId, NodeExecutionContext context)> executions;

  setUp(() {
    executions = <(String, NodeExecutionContext)>[];
    h = EngineHarness(
      registerNodes: (registry) {
        for (final descriptor in [
          NodeDescriptors.claudeCode,
          NodeDescriptors.codex,
          NodeDescriptors.geminiCli,
        ]) {
          registry.register(
            descriptor,
            () => _FakeHarnessNode(
              descriptor: descriptor,
              script: h.script,
              executions: executions,
            ),
          );
        }
      },
    );
  });

  WorkflowNode claudeNode(
    String id, {
    List<Map<String, Object?>>? fallback,
    String? model = 'm0',
    String? effort = 'high',
    List<String> extraArgs = const ['--foo'],
  }) => WorkflowNode(
    id: id,
    type: NodeTypeId.claudeCode,
    label: id,
    position: const WorkflowPosition(x: 0, y: 0),
    config: <String, Object?>{
      'additionalInstructions': 'x',
      'model': model,
      'effort': effort,
      'extraArgs': extraArgs,
      'fallback':
          fallback ??
          const [
            <String, Object?>{'harness': NodeTypeId.codex, 'model': 'm1'},
            <String, Object?>{'harness': NodeTypeId.claudeCode, 'model': 'm2'},
          ],
    },
  );

  Workflow singleHarnessFlow({WorkflowNode? node}) => Workflow(
    id: 'wf-1',
    name: 'Fallback flow',
    nodes: [node ?? claudeNode('a')],
    edges: const [],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    entryNodeId: 'a',
  );

  Future<Result<Run>> startRun(
    Workflow wf, {
    String id = runId,
    String? parentRunId,
  }) async {
    await h.runs.create(
      Run(
        id: id,
        workflowName: wf.name,
        workflowDefinition: wf,
        workspaceRoot: '/workspace',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
        parentRunId: parentRunId,
      ),
    );
    return await h.engine.start(id);
  }

  group('GraphEngine rate-limit fallback', () {
    test(
      'rate limit switches to the next entry and emits node.fallback',
      () async {
        h.script.on('a', [_rateLimit('quota'), outcome(NodeOutput.onSuccess)]);

        final result = await startRun(singleHarnessFlow());

        expect(result.valueOrNull?.status, RunStatus.succeeded);
        expect(executions.map((e) => e.$1).toList(), [
          NodeTypeId.claudeCode,
          NodeTypeId.codex,
        ]);

        final fallbacks = h.events.ofType(runId, RunEventType.nodeFallback);
        expect(fallbacks, hasLength(1));
        expect(fallbacks.single.nodeId, 'a');
        expect(fallbacks.single.payload, {
          'from': {'harness': NodeTypeId.claudeCode, 'model': 'm0'},
          'to': {'harness': NodeTypeId.codex, 'model': 'm1'},
          'reason': 'quota',
        });
        expect(h.events.ofType(runId, RunEventType.nodeFailed), isEmpty);
      },
    );

    test(
      'effective config drops extraArgs for different harness and keeps it for '
      'same harness',
      () async {
        h.script.on('a', [
          _rateLimit('q0'),
          _rateLimit('q1', harness: NodeTypeId.codex),
          outcome(NodeOutput.onSuccess),
        ]);

        final result = await startRun(singleHarnessFlow());

        expect(result.valueOrNull?.status, RunStatus.succeeded);
        expect(executions, hasLength(3));

        final codexCfg = executions[1].$2.config;
        expect(codexCfg['model'], 'm1');
        expect(codexCfg.containsKey('effort'), isFalse);
        expect(codexCfg.containsKey('extraArgs'), isFalse);
        expect(codexCfg['additionalInstructions'], 'x');

        final secondClaudeCfg = executions[2].$2.config;
        expect(secondClaudeCfg['model'], 'm2');
        expect(secondClaudeCfg['extraArgs'], ['--foo']);
      },
    );

    test(
      'stoppedAttempt is set only on the attempt right after a switch',
      () async {
        h.script.on('a', [_rateLimit('q0'), outcome(NodeOutput.onSuccess)]);

        await startRun(singleHarnessFlow());

        expect(executions[0].$2.stoppedAttempt, isNull);
        expect(executions[1].$2.stoppedAttempt?.harness, NodeTypeId.claudeCode);
        expect(executions[1].$2.stoppedAttempt?.model, 'm0');
      },
    );

    test(
      'circuit breaker and edge attempts are untouched by fallback switch',
      () async {
        h.script.on('a', [
          infraFailure(),
          _rateLimit('q0'),
          infraFailure(),
          infraFailure(),
        ]);

        final result = await startRun(singleHarnessFlow());

        expect(result.valueOrNull?.status, RunStatus.failed);
        expect(h.run.errorMessage, contains('Circuit breaker'));
        expect(h.script.runsOf('a'), 4);

        final switchCp = h.checkpoints.checkpoints.first;
        expect(switchCp.circuitBreakerCount, 1);
        expect(switchCp.attemptsByEdge, isEmpty);
      },
    );

    test('does not restore snapshot on fallback switch', () async {
      h.script.on('a', [_rateLimit('q0'), outcome(NodeOutput.onSuccess)]);

      await startRun(singleHarnessFlow());

      expect(h.snapshots.restored, isEmpty);
      expect(h.eventTypes, isNot(contains(RunEventType.snapshotRestored)));
    });

    test('exhausted fallback list fails with the last entry failure', () async {
      h.script.on('a', [
        _rateLimit('q0'),
        _rateLimit('q1', harness: NodeTypeId.codex),
        _rateLimit('q2'),
      ]);

      final result = await startRun(singleHarnessFlow());

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.script.runsOf('a'), 3);
      expect(h.run.errorMessage, contains('q2'));
      expect(h.events.ofType(runId, RunEventType.nodeFallback), hasLength(2));
      expect(h.events.ofType(runId, RunEventType.nodeFailed), hasLength(1));
    });

    test('sign-in failure never falls back', () async {
      h.script.on('a', [_authFailure('login required')]);

      final result = await startRun(singleHarnessFlow());

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.script.runsOf('a'), 1);
      expect(h.events.ofType(runId, RunEventType.nodeFallback), isEmpty);

      // Rate limit then auth failure on entry 0 fails after 2 runs.
      executions.clear();
      late final EngineHarness h2;
      h2 = EngineHarness(
        registerNodes: (registry) {
          for (final descriptor in [
            NodeDescriptors.claudeCode,
            NodeDescriptors.codex,
          ]) {
            registry.register(
              descriptor,
              () => _FakeHarnessNode(
                descriptor: descriptor,
                script: h2.script,
                executions: executions,
              ),
            );
          }
        },
      );
      h2.script.on('a', [
        _rateLimit('q0'),
        _authFailure('codex login', harness: NodeTypeId.codex),
      ]);
      await h2.createRun(singleHarnessFlow());
      final r2 = await h2.engine.start(runId);
      expect(r2.valueOrNull?.status, RunStatus.failed);
      expect(executions, hasLength(2));
      expect(h2.events.ofType(runId, RunEventType.nodeFallback), hasLength(1));
    });

    test('infra failure on a fallback entry stays on that entry', () async {
      h.script.on('a', [
        _rateLimit('q0'),
        infraFailure(),
        outcome(NodeOutput.onSuccess),
      ]);

      final result = await startRun(singleHarnessFlow());

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(executions.map((e) => e.$1).toList(), [
        NodeTypeId.claudeCode,
        NodeTypeId.codex,
        NodeTypeId.codex,
      ]);
    });

    test('sticky on a loop edge and stoppedAttempt is one-shot', () async {
      final wf = Workflow(
        id: 'wf-loop',
        name: 'Loop',
        nodes: [claudeNode('coder'), fakeNode('tests'), fakeNode('done')],
        edges: [
          edge('coder', NodeOutput.onSuccess, 'tests'),
          edge('tests', NodeOutput.onFailure, 'coder', maxRetries: 2),
          edge('tests', NodeOutput.onSuccess, 'done'),
        ],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        entryNodeId: 'coder',
      );
      h.script.on('coder', [
        _rateLimit('q0'),
        outcome(NodeOutput.onSuccess),
        outcome(NodeOutput.onSuccess),
      ]);
      h.script.on('tests', [
        outcome(NodeOutput.onFailure),
        outcome(NodeOutput.onSuccess),
      ]);

      final result = await startRun(wf);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(executions.map((e) => e.$1).toList(), [
        NodeTypeId.claudeCode,
        NodeTypeId.codex,
        NodeTypeId.codex,
      ]);
      expect(executions[1].$2.stoppedAttempt, isNotNull);
      expect(executions[2].$2.stoppedAttempt, isNull);
      expect(h.checkpoints.checkpoints.last.fallbackIndexByNodeId, {
        'coder': 0,
      });
    });

    test('restores fallbackIndexByNodeId after interrupted resume', () async {
      await h.createRun(singleHarnessFlow());
      await h.checkpoints.append(
        id: 'cp-seed',
        runId: runId,
        pendingNodeIds: const ['a'],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {},
        fallbackIndexByNodeId: const {'a': 0},
        createdAt: h.tick(),
      );
      await h.recovery.recoverOrphanedRuns();
      h.script.on('a', [outcome(NodeOutput.onSuccess)]);

      final result = await h.engine.resume(runId);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(executions.map((e) => e.$1).toList(), [NodeTypeId.codex]);
    });

    test('new run of same workflow starts at own harness', () async {
      h.script.on('a', [
        _rateLimit('q0'),
        outcome(NodeOutput.onSuccess),
        outcome(NodeOutput.onSuccess),
      ]);
      final wf = singleHarnessFlow();
      await startRun(wf);

      executions.clear();
      await startRun(wf, id: 'run-2');

      expect(executions.map((e) => e.$1).toList(), [NodeTypeId.claudeCode]);
    });

    test('fan-out child run starts at own harness', () async {
      h.script.on('a', [outcome(NodeOutput.onSuccess)]);
      final result = await startRun(
        singleHarnessFlow(),
        parentRunId: 'parent-1',
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(executions.map((e) => e.$1).toList(), [NodeTypeId.claudeCode]);
    });

    test(
      'pending ask_human is discarded when node fails with rate limit',
      () async {
        h.script.on('a', [
          (context) async {
            unawaited(
              h.gateway.requestHumanAnswer(
                runId: context.runId,
                nodeId: context.nodeId,
                attempt: context.attempt,
                question: 'Which option?',
              ),
            );
            await Future<void>.delayed(Duration.zero);
            return const FailureResult(
              HarnessRateLimitFailure('q0', harnessType: NodeTypeId.claudeCode),
            );
          },
          outcome(NodeOutput.onSuccess),
        ]);

        final result = await startRun(singleHarnessFlow());

        expect(result.valueOrNull?.status, RunStatus.succeeded);
        expect(h.gateway.pendingForRun(runId), isEmpty);
        expect(
          (await h.pauses.listPendingForRun(runId)).valueOrNull!
              .where((p) => p.nodeId == 'a'),
          isEmpty,
        );
        expect(executions.map((e) => e.$1).toList(), [
          NodeTypeId.claudeCode,
          NodeTypeId.codex,
        ]);
      },
    );

    test(
      'cancel while running does not trigger fallback on rate limit',
      () async {
        final started = Completer<void>();
        final finish = Completer<Result<NodeOutcome>>();
        h.script.on('a', [
          (_) {
            started.complete();
            return finish.future;
          },
        ]);

        await h.createRun(singleHarnessFlow());
        final runFuture = h.engine.start(runId);
        await started.future;

        final cancelFuture = h.engine.cancel(runId);
        finish.complete(
          const FailureResult(
            HarnessRateLimitFailure('q0', harnessType: NodeTypeId.claudeCode),
          ),
        );

        final result = await runFuture;
        await cancelFuture;
        expect(result.valueOrNull?.status, RunStatus.cancelled);
        expect(h.events.ofType(runId, RunEventType.nodeFallback), isEmpty);
      },
    );
  });
}
