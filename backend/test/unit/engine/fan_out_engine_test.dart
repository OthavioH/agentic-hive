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

Workflow _parentWorkflow({int maxItems = 20, bool withOnFailureEdge = false}) =>
    Workflow(
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
            'concurrency': 2,
            'maxItems': maxItems,
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

      expect(h.run.status, RunStatus.succeeded);
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
}
