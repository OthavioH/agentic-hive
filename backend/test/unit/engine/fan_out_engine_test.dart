import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';

final class _FakeProcessRunner implements ProcessRunner {
  const new();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeWorkspaceRepository implements WorkspaceRepository {
  @override
  Future<Result<Workspace>> getById(String id) async => Success(
    Workspace(
      id: id,
      name: 'Workspace',
      rootPath: '.',
      isGit: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SingleWorkflowRepository implements WorkflowRepository {
  new(this.workflow);

  final Workflow workflow;

  @override
  Future<Result<Workflow>> getById(String id) async => Success(workflow);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Workflow _parentWorkflow({
  int maxItems = 20,
  int concurrency = 1,
  bool withOnFailureEdge = false,
}) => Workflow(
  id: 'parent-wf',
  name: 'Parent Flow',
  entryNodeId: 'seed',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  nodes: [
    fakeNode('seed'),
    WorkflowNode(
      id: 'fan',
      type: NodeTypeId.fanOut,
      label: 'Fan',
      position: const WorkflowPosition(x: 200, y: 0),
      config: {
        'workflowId': 'child-wf',
        'itemsNodeId': 'seed',
        'itemsPath': 'items',
        'maxItems': maxItems,
        'concurrency': concurrency,
      },
    ),
    if (withOnFailureEdge) fakeNode('recover'),
  ],
  edges: [
    edge('seed', NodeOutput.onSuccess, 'fan'),
    if (withOnFailureEdge) edge('fan', NodeOutput.onFailure, 'recover'),
  ],
);

void main() {
  late EngineHarness h;
  late RunService service;

  setUp(() {
    late final RunService svc;
    h = EngineHarness(childRuns: () => svc);
    final childWorkflow = Workflow(
      id: 'child-wf',
      name: 'Child Flow',
      entryNodeId: 'work',
      edges: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      nodes: [fakeNode('work')],
    );
    svc = RunService(
      runs: h.runs,
      checkpoints: h.checkpoints,
      events: h.events,
      workspaces: WorkspaceService(
        workspaces: _FakeWorkspaceRepository(),
        capabilities: const WorkspaceCapabilitiesService(
          GitClient(_FakeProcessRunner()),
        ),
      ),
      workflows: _SingleWorkflowRepository(childWorkflow),
      engine: h.engine,
      workspacePreparation: const WorkspacePreparationService(
        git: GitClient(_FakeProcessRunner()),
      ),
    );
    service = svc;
  });

  tearDown(() async {
    await service.waitForActiveExecutions();
  });

  test('parent succeeds when all children succeed and lists them', () async {
    h.script.on('seed', [
      (_) async => const Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {
            'items': ['a', 'b', 'c'],
          },
        ),
      ),
    ]);
    h.script.on('work', [
      (ctx) async => Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {'got': ctx.runInput},
        ),
      ),
      (ctx) async => Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {'got': ctx.runInput},
        ),
      ),
      (ctx) async => Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {'got': ctx.runInput},
        ),
      ),
    ]);

    await h.runs.create(
      Run(
        id: 'run-1',
        workflowId: 'parent-wf',
        workflowName: 'Parent Flow',
        workflowDefinition: _parentWorkflow(),
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
      ),
    );
    await h.engine.start('run-1');
    await service.waitForActiveExecutions();

    expect(h.run.status, RunStatus.succeeded);
    final cp = (await h.checkpoints.getLatestForRun('run-1')).valueOrNull!;
    final fanOut = cp.nodeOutputs['fan']!;
    final data = fanOut['data']! as Map<String, Object?>;
    expect(data['succeeded'], 3);

    final children =
        h.runs.runs.values.where((r) => r.parentRunId == 'run-1').toList()
          ..sort((a, b) => a.childIndex!.compareTo(b.childIndex!));
    expect(children, hasLength(3));
    expect(children.map((c) => c.parentNodeId), ['fan', 'fan', 'fan']);
    expect(children.map((c) => c.childIndex), [0, 1, 2]);
  });

  test('failing child emits onFailure and continues on edge', () async {
    h.script.on('seed', [
      (_) async => const Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {
            'items': ['a', 'b'],
          },
        ),
      ),
    ]);
    h.script.on('work', [
      (_) async =>
          const Success(NodeOutcome(outputLabel: NodeOutput.onSuccess)),
      (_) async =>
          const Success(NodeOutcome(outputLabel: NodeOutput.onFailure)),
    ]);
    h.script.on('recover', [
      (_) async =>
          const Success(NodeOutcome(outputLabel: NodeOutput.onSuccess)),
    ]);

    await h.runs.create(
      Run(
        id: 'run-1',
        workflowId: 'parent-wf',
        workflowName: 'Parent Flow',
        workflowDefinition: _parentWorkflow(withOnFailureEdge: true),
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
      ),
    );
    await h.engine.start('run-1');
    await service.waitForActiveExecutions();

    expect(h.run.status, RunStatus.succeeded);
    final cp = (await h.checkpoints.getLatestForRun('run-1')).valueOrNull!;
    final fanOut = cp.nodeOutputs['fan']!;
    expect(fanOut['outputLabel'], NodeOutput.onFailure);
  });

  test(
    'with no onFailure edge a failing child ends the parent as failed',
    () async {
      h.script.on('seed', [
        (_) async => const Success(
          NodeOutcome(
            outputLabel: NodeOutput.onSuccess,
            data: {
              'items': ['a'],
            },
          ),
        ),
      ]);
      h.script.on('work', [
        (_) async =>
            const Success(NodeOutcome(outputLabel: NodeOutput.onFailure)),
      ]);

      await h.runs.create(
        Run(
          id: 'run-1',
          workflowId: 'parent-wf',
          workflowName: 'Parent Flow',
          workflowDefinition: _parentWorkflow(),
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );
      await h.engine.start('run-1');
      await service.waitForActiveExecutions();

      expect(h.run.status, RunStatus.failed);
    },
  );

  test(
    'empty list: parent succeeds and has a snapshot.warning event',
    () async {
      h.script.on('seed', [
        (_) async => const Success(
          NodeOutcome(
            outputLabel: NodeOutput.onSuccess,
            data: {'items': <Object?>[]},
          ),
        ),
      ]);

      await h.runs.create(
        Run(
          id: 'run-1',
          workflowId: 'parent-wf',
          workflowName: 'Parent Flow',
          workflowDefinition: _parentWorkflow(),
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );
      await h.engine.start('run-1');

      expect(h.run.status, RunStatus.succeeded, reason: h.run.errorMessage);
      expect(
        h.events.ofType('run-1', RunEventType.snapshotWarning),
        hasLength(1),
      );
    },
  );

  test('over the cap: parent fails and no child run exists', () async {
    h.script.on('seed', [
      (_) async => const Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {
            'items': ['a', 'b', 'c'],
          },
        ),
      ),
    ]);

    await h.runs.create(
      Run(
        id: 'run-1',
        workflowId: 'parent-wf',
        workflowName: 'Parent Flow',
        workflowDefinition: _parentWorkflow(maxItems: 2),
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
      ),
    );
    await h.engine.start('run-1');

    expect(h.run.status, RunStatus.failed);
    expect(h.runs.runs.values.where((r) => r.parentRunId == 'run-1'), isEmpty);
  });

  test(
    'cancelling the parent cancels every running child and reports cancelled',
    () async {
      final hung = <String, Completer<void>>{};
      h.killer.onKill = (runId, nodeId) => hung[runId]?.complete();

      h.script.on('seed', [
        (_) async => const Success(
          NodeOutcome(
            outputLabel: NodeOutput.onSuccess,
            data: {
              'items': ['a', 'b', 'c'],
            },
          ),
        ),
      ]);
      h.script.on('work', [
        for (var i = 0; i < 3; i++)
          (ctx) async {
            final c = hung.putIfAbsent(ctx.runId, Completer<void>.new);
            await c.future;
            return const FailureResult(NodeExecutionFailure('killed'));
          },
      ]);

      await h.runs.create(
        Run(
          id: 'run-1',
          workflowId: 'parent-wf',
          workflowName: 'Parent Flow',
          workflowDefinition: _parentWorkflow(concurrency: 2),
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );
      final startFuture = h.engine.start('run-1');
      await h.settle();
      while (hung.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      await h.engine.cancel('run-1');
      await startFuture;
      await service.waitForActiveExecutions();

      expect(h.run.status, RunStatus.cancelled);
      final children = h.runs.runs.values
          .where((r) => r.parentRunId == 'run-1')
          .toList();
      expect(children, hasLength(1));
      for (final c in children) {
        expect(c.status, RunStatus.cancelled);
      }
      final parentKillIndex = h.killer.kills.indexWhere((k) => k.$1 == 'run-1');
      expect(parentKillIndex, isNonNegative);
      for (final c in children) {
        final childKillIndex = h.killer.kills.indexWhere((k) => k.$1 == c.id);
        expect(childKillIndex, isNonNegative);
        expect(childKillIndex, lessThan(parentKillIndex));
      }
    },
  );

  test(
    'parent is cancellationUncertain when a child cannot be confirmed stopped',
    () async {
      final hung = <String, Completer<void>>{};
      h.killer.failure = const NodeExecutionFailure('stuck');
      h.killer.onKill = (runId, nodeId) => hung[runId]?.complete();

      h.script.on('seed', [
        (_) async => const Success(
          NodeOutcome(
            outputLabel: NodeOutput.onSuccess,
            data: {
              'items': ['a'],
            },
          ),
        ),
      ]);
      h.script.on('work', [
        (ctx) async {
          final c = hung.putIfAbsent(ctx.runId, Completer<void>.new);
          await c.future;
          return const FailureResult(NodeExecutionFailure('killed'));
        },
      ]);

      await h.runs.create(
        Run(
          id: 'run-1',
          workflowId: 'parent-wf',
          workflowName: 'Parent Flow',
          workflowDefinition: _parentWorkflow(),
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );
      final startFuture = h.engine.start('run-1');
      await h.settle();
      while (hung.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      await h.engine.cancel('run-1');
      await startFuture;
      await service.waitForActiveExecutions();

      expect(h.run.status, RunStatus.cancellationUncertain);
      expect(h.run.errorMessage, contains('Could not confirm'));
    },
  );

  test(
    'cancelling an interrupted parent cancels its interrupted children',
    () async {
      await h.runs.create(
        Run(
          id: 'run-1',
          workflowId: 'parent-wf',
          workflowName: 'Parent Flow',
          workflowDefinition: _parentWorkflow(),
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.interrupted,
          startedAt: DateTime.utc(2026),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await h.runs.create(
          Run(
            id: 'c-$i',
            workflowId: 'child-wf',
            workflowName: 'Child Flow',
            workflowDefinition: _parentWorkflow(),
            workspacePath: '.',
            workspaceId: 'ws-1',
            status: RunStatus.interrupted,
            startedAt: DateTime.utc(2026, 1, 1, 0, i + 1),
            parentRunId: 'run-1',
            parentNodeId: 'fan',
            childIndex: i,
          ),
        );
      }

      await h.engine.cancel('run-1');

      expect(h.run.status, RunStatus.cancelled);
      expect(h.runs.runs['c-0']!.status, RunStatus.cancelled);
      expect(h.runs.runs['c-1']!.status, RunStatus.cancelled);
    },
  );

  test(
    'cancelling one child does not cancel the parent or its siblings',
    () async {
      final hung = <String, Completer<void>>{};
      final siblingRelease = Completer<void>();
      h.killer.onKill = (runId, nodeId) => hung[runId]?.complete();

      h.script.on('seed', [
        (_) async => const Success(
          NodeOutcome(
            outputLabel: NodeOutput.onSuccess,
            data: {
              'items': ['a', 'b'],
            },
          ),
        ),
      ]);
      var callCount = 0;
      h.script.on('work', [
        (ctx) async {
          final idx = callCount++;
          if (idx == 0) {
            final c = hung.putIfAbsent(ctx.runId, Completer<void>.new);
            await c.future;
            return const FailureResult(NodeExecutionFailure('killed'));
          }
          await siblingRelease.future;
          return const Success(
            NodeOutcome(outputLabel: NodeOutput.onSuccess, data: {'ok': true}),
          );
        },
        (ctx) async {
          await siblingRelease.future;
          return const Success(
            NodeOutcome(outputLabel: NodeOutput.onSuccess, data: {'ok': true}),
          );
        },
      ]);

      await h.runs.create(
        Run(
          id: 'run-1',
          workflowId: 'parent-wf',
          workflowName: 'Parent Flow',
          workflowDefinition: _parentWorkflow(concurrency: 2),
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );
      final startFuture = h.engine.start('run-1');
      await h.settle();
      while (hung.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final firstChildId = hung.keys.single;
      await h.engine.cancel(firstChildId);
      expect(h.run.status, RunStatus.running);

      siblingRelease.complete();
      await startFuture;
      await service.waitForActiveExecutions();

      expect(h.run.status, RunStatus.failed);
      final children = h.runs.runs.values
          .where((r) => r.parentRunId == 'run-1')
          .toList();
      final sibling = children.firstWhere((c) => c.id != firstChildId);
      expect(sibling.status, RunStatus.succeeded);
    },
  );

  test('a failing parent branch cancels the children', () async {
    final hung = <String, Completer<void>>{};
    final badGate = Completer<void>();
    h.killer.onKill = (runId, nodeId) => hung[runId]?.complete();

    final branchedWorkflow = Workflow(
      id: 'parent-wf',
      name: 'Parent Flow',
      nodes: const [
        WorkflowNode(
          id: 'seed',
          type: 'command',
          label: 'Seed',
          position: WorkflowPosition(x: 0, y: 0),
        ),
        WorkflowNode(
          id: 'fan',
          type: 'fan_out',
          label: 'Fan',
          position: WorkflowPosition(x: 200, y: 0),
          config: {
            'workflowId': 'child-wf',
            'itemsNodeId': 'seed',
            'itemsPath': 'items',
          },
        ),
        WorkflowNode(
          id: 'bad',
          type: 'command',
          label: 'Bad',
          position: WorkflowPosition(x: 200, y: 120),
        ),
      ],
      edges: const [
        WorkflowEdge(
          id: 'e1',
          sourceNodeId: 'seed',
          sourceOutput: NodeOutput.onSuccess,
          targetNodeId: 'fan',
        ),
        WorkflowEdge(
          id: 'e2',
          sourceNodeId: 'seed',
          sourceOutput: NodeOutput.onSuccess,
          targetNodeId: 'bad',
        ),
      ],
      entryNodeId: 'seed',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    h.script.on('seed', [
      (_) async => const Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {
            'items': ['a'],
          },
        ),
      ),
    ]);
    h.script.on('work', [
      (ctx) async {
        final c = hung.putIfAbsent(ctx.runId, Completer<void>.new);
        await c.future;
        return const FailureResult(NodeExecutionFailure('killed'));
      },
    ]);
    h.script.on('bad', [
      (_) async {
        await badGate.future;
        return const Success(NodeOutcome(outputLabel: NodeOutput.onFailure));
      },
    ]);

    await h.runs.create(
      Run(
        id: 'run-1',
        workflowId: 'parent-wf',
        workflowName: 'Parent Flow',
        workflowDefinition: branchedWorkflow,
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
      ),
    );
    final startFuture = h.engine.start('run-1');
    await h.settle();
    while (hung.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    badGate.complete();
    await startFuture;
    await service.waitForActiveExecutions();

    expect(h.run.status, RunStatus.failed);
    final children = h.runs.runs.values
        .where((r) => r.parentRunId == 'run-1')
        .toList();
    expect(children, hasLength(1));
    expect(children.single.status, RunStatus.cancelled);
    final failedEvents = h.events.ofType('run-1', RunEventType.runFailed);
    expect(
      failedEvents.single.payload.containsKey('kill_unconfirmed'),
      isFalse,
    );
  });

  test(
    'retrying the fan-out node after a failure only restarts the failed item',
    () async {
      final retryWorkflow = Workflow(
        id: 'parent-wf',
        name: 'Parent Flow',
        nodes: [
          fakeNode('seed'),
          const WorkflowNode(
            id: 'fan',
            type: 'fan_out',
            label: 'Fan',
            position: WorkflowPosition(x: 200, y: 0),
            config: {
              'workflowId': 'child-wf',
              'itemsNodeId': 'seed',
              'itemsPath': 'items',
              'concurrency': 2,
            },
          ),
          fakeNode('done'),
        ],
        edges: const [
          WorkflowEdge(
            id: 'e1',
            sourceNodeId: 'seed',
            sourceOutput: NodeOutput.onSuccess,
            targetNodeId: 'fan',
          ),
          WorkflowEdge(
            id: 'e2',
            sourceNodeId: 'fan',
            sourceOutput: NodeOutput.onFailure,
            targetNodeId: 'seed',
            maxRetries: 1,
          ),
          WorkflowEdge(
            id: 'e3',
            sourceNodeId: 'fan',
            sourceOutput: NodeOutput.onSuccess,
            targetNodeId: 'done',
          ),
        ],
        entryNodeId: 'seed',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      h.script.on('seed', [
        (_) async => const Success(
          NodeOutcome(
            outputLabel: NodeOutput.onSuccess,
            data: {
              'items': ['a', 'b'],
            },
          ),
        ),
        (_) async => const Success(
          NodeOutcome(
            outputLabel: NodeOutput.onSuccess,
            data: {
              'items': ['a', 'b'],
            },
          ),
        ),
      ]);
      var workRuns = 0;
      h.script.on('work', [
        (_) async {
          workRuns++;
          return const Success(
            NodeOutcome(outputLabel: NodeOutput.onSuccess, data: {'v': 1}),
          );
        },
        (_) async {
          workRuns++;
          return const FailureResult(UnexpectedFailure('boom'));
        },
        (_) async {
          workRuns++;
          return const Success(
            NodeOutcome(outputLabel: NodeOutput.onSuccess, data: {'v': 2}),
          );
        },
      ]);

      await h.runs.create(
        Run(
          id: 'run-1',
          workflowId: 'parent-wf',
          workflowName: 'Parent Flow',
          workflowDefinition: retryWorkflow,
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );
      await h.engine.start('run-1');
      await service.waitForActiveExecutions();

      expect(h.run.status, RunStatus.succeeded, reason: h.run.errorMessage);
      expect(workRuns, 3);
      final children =
          h.runs.runs.values.where((r) => r.parentRunId == 'run-1').toList()
            ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      expect(children, hasLength(3));

      final cp = h.checkpoints.checkpoints.lastWhere((c) => c.runId == 'run-1');
      final fanOut = cp.nodeOutputs['fan']!['data']! as Map<String, Object?>;
      expect(fanOut['succeeded'], 2);
      final entries = (fanOut['children']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(entries[0]['runId'], children[0].id);
    },
  );

  test(
    'restart: resuming the parent adopts children instead of duplicating them',
    () async {
      await h.runs.create(
        Run(
          id: 'run-1',
          workflowId: 'parent-wf',
          workflowName: 'Parent Flow',
          workflowDefinition: _parentWorkflow(),
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.interrupted,
          startedAt: DateTime.utc(2026),
        ),
      );
      final cw = Workflow(
        id: 'child-wf',
        name: 'Child Flow',
        entryNodeId: 'work',
        nodes: [fakeNode('work')],
        edges: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await h.runs.create(
        Run(
          id: 'c-ok',
          workflowId: 'child-wf',
          workflowName: 'Child Flow',
          workflowDefinition: cw,
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 1, 1, 0, 1),
          parentRunId: 'run-1',
          parentNodeId: 'fan',
          childIndex: 0,
        ),
      );
      await h.runs.create(
        Run(
          id: 'c-int',
          workflowId: 'child-wf',
          workflowName: 'Child Flow',
          workflowDefinition: cw,
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.interrupted,
          startedAt: DateTime.utc(2026, 1, 1, 0, 2),
          parentRunId: 'run-1',
          parentNodeId: 'fan',
          childIndex: 1,
        ),
      );

      h.script.on('seed', [
        (_) async => const Success(
          NodeOutcome(
            outputLabel: NodeOutput.onSuccess,
            data: {
              'items': ['a', 'b'],
            },
          ),
        ),
      ]);
      var workRuns = 0;
      h.script.on('work', [
        (_) async {
          workRuns++;
          return const Success(
            NodeOutcome(
              outputLabel: NodeOutput.onSuccess,
              data: {'done': true},
            ),
          );
        },
      ]);

      await service.resumeRun('run-1');
      await service.waitForActiveExecutions();

      expect(h.run.status, RunStatus.succeeded, reason: h.run.errorMessage);
      expect(workRuns, 1);
      final children = h.runs.runs.values
          .where((r) => r.parentRunId == 'run-1')
          .toList();
      expect(children, hasLength(2));
      expect(h.runs.runs['c-int']!.status, RunStatus.succeeded);

      final cp = h.checkpoints.checkpoints.lastWhere((c) => c.runId == 'run-1');
      final fanOut = cp.nodeOutputs['fan']!['data']! as Map<String, Object?>;
      final entries = (fanOut['children']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(entries.map((e) => e['runId']), ['c-ok', 'c-int']);
    },
  );

  test('a paused child leaves the parent running and siblings going', () async {
    final child0Gate = Completer<void>();

    h.script.on('seed', [
      (_) async => const Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {
            'items': ['a', 'b'],
          },
        ),
      ),
    ]);
    var idx = 0;
    h.script.on('work', [
      (_) async {
        if (idx++ == 0) {
          await child0Gate.future;
        }
        return const Success(NodeOutcome(outputLabel: NodeOutput.onSuccess));
      },
      (_) async {
        if (idx++ == 0) {
          await child0Gate.future;
        }
        return const Success(NodeOutcome(outputLabel: NodeOutput.onSuccess));
      },
    ]);

    await h.runs.create(
      Run(
        id: 'run-1',
        workflowId: 'parent-wf',
        workflowName: 'Parent Flow',
        workflowDefinition: _parentWorkflow(concurrency: 2),
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
      ),
    );
    final startFuture = h.engine.start('run-1');
    await h.settle();
    while (idx == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(h.run.status, RunStatus.running);
    child0Gate.complete();
    await startFuture;
    await service.waitForActiveExecutions();
    expect(h.run.status, RunStatus.succeeded, reason: h.run.errorMessage);
  });
}
