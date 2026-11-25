import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../engine/support/engine_harness.dart';

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
      createdAt: DateTime.utc(2026, 11, 23, 10),
      updatedAt: DateTime.utc(2026, 11, 23, 10),
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

void main() {
  late EngineHarness harness;
  late Workflow savedWorkflow;
  late RunService service;

  setUp(() {
    harness = EngineHarness();
    savedWorkflow = Workflow(
      id: 'wf-1',
      name: 'Override Test Workflow',
      entryNodeId: 'h',
      edges: const <WorkflowEdge>[],
      createdAt: DateTime.utc(2026, 11, 23, 10),
      updatedAt: DateTime.utc(2026, 11, 23, 10),
      nodes: const <WorkflowNode>[
        WorkflowNode(
          id: 'h',
          type: NodeTypeId.claudeCode,
          label: 'Claude',
          position: WorkflowPosition(x: 0, y: 0),
          config: <String, Object?>{
            'agentId': 'old',
            'model': 'm0',
            'effort': 'low',
          },
        ),
        WorkflowNode(
          id: 'c',
          type: NodeTypeId.command,
          label: 'Command',
          position: WorkflowPosition(x: 100, y: 0),
          config: <String, Object?>{'command': 'echo hi'},
        ),
      ],
    );
    service = RunService(
      runs: harness.runs,
      checkpoints: harness.checkpoints,
      events: harness.events,
      workspaces: WorkspaceService(
        workspaces: _FakeWorkspaceRepository(),
        capabilities: const WorkspaceCapabilitiesService(
          GitClient(_FakeProcessRunner()),
        ),
      ),
      workflows: _SingleWorkflowRepository(savedWorkflow),
      engine: harness.engine,
      workspacePreparation: const WorkspacePreparationService(
        git: GitClient(_FakeProcessRunner()),
      ),
    );
  });

  StartRunRequest makeRequest({
    Map<String, NodeOverride>? nodeOverrides,
    RunTarget? target,
  }) => StartRunRequest(
    workflowId: 'wf-1',
    workspaceId: 'ws-1',
    target: target,
    nodeOverrides: nodeOverrides,
  );

  test('no overrides uses saved workflow', () async {
    final result = await service.startRun(makeRequest());
    expect(result, isA<Success<Run>>());
    final run = result.valueOrNull!;
    expect(run.workflowDefinition, savedWorkflow);
    await service.waitForActiveExecutions();
  });

  test('empty overrides map uses saved workflow', () async {
    final result = await service.startRun(
      makeRequest(nodeOverrides: const <String, NodeOverride>{}),
    );
    expect(result, isA<Success<Run>>());
    final run = result.valueOrNull!;
    expect(run.workflowDefinition, savedWorkflow);
    await service.waitForActiveExecutions();
  });

  test('valid overrides apply to returned run and persisted row', () async {
    final result = await service.startRun(
      makeRequest(
        nodeOverrides: const {'h': NodeOverride(model: 'm1', effort: 'high')},
      ),
    );
    expect(result, isA<Success<Run>>());
    final run = result.valueOrNull!;
    final h = run.workflowDefinition.nodes.firstWhere((n) => n.id == 'h');
    expect(h.config['model'], 'm1');
    expect(h.config['effort'], 'high');
    expect(h.config['agentId'], 'old');
    expect(run.workflowId, 'wf-1');

    final persisted = await harness.runs.getById(run.id);
    expect(persisted.valueOrNull?.workflowDefinition, run.workflowDefinition);
    await service.waitForActiveExecutions();
  });

  test('saved workflow in repository is unchanged after startRun', () async {
    final result = await service.startRun(
      makeRequest(
        nodeOverrides: const {'h': NodeOverride(model: 'm1', effort: 'high')},
      ),
    );
    expect(result, isA<Success<Run>>());
    final h = savedWorkflow.nodes.firstWhere((n) => n.id == 'h');
    expect(h.config['model'], 'm0');
    expect(h.config['effort'], 'low');
    await service.waitForActiveExecutions();
  });

  test(
    'unknown node id returns ValidationFailure and creates no run',
    () async {
      final result = await service.startRun(
        makeRequest(nodeOverrides: const {'zzz': NodeOverride(model: 'm1')}),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
      final failure = result.failureOrNull! as ValidationFailure;
      expect(failure.message, contains('Invalid node overrides'));
      expect(failure.details, contains('nodeOverrides.zzz'));
      expect((await harness.runs.list()).valueOrNull!.items, isEmpty);
    },
  );

  test('bad effort returns ValidationFailure and creates no run', () async {
    final result = await service.startRun(
      makeRequest(nodeOverrides: const {'h': NodeOverride(effort: 'turbo')}),
    );
    expect(result.failureOrNull, isA<ValidationFailure>());
    final failure = result.failureOrNull! as ValidationFailure;
    expect(failure.details, contains('nodeOverrides.h.effort'));
    expect((await harness.runs.list()).valueOrNull!.items, isEmpty);
  });

  test('unsupported field on command node returns ValidationFailure', () async {
    final result = await service.startRun(
      makeRequest(nodeOverrides: const {'c': NodeOverride(model: 'm')}),
    );
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect((await harness.runs.list()).valueOrNull!.items, isEmpty);
  });

  test('empty NodeOverride returns ValidationFailure', () async {
    final result = await service.startRun(
      makeRequest(nodeOverrides: const {'h': NodeOverride()}),
    );
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect((await harness.runs.list()).valueOrNull!.items, isEmpty);
  });

  test(
    'order guard: invalid override fails before worktree target resolution',
    () async {
      final result = await service.startRun(
        makeRequest(
          target: const RunTarget.newWorktree(),
          nodeOverrides: const {'zzz': NodeOverride(model: 'm1')},
        ),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    },
  );
}
