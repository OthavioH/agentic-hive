import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/nodes/child_run_port.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_canceller.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
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

final class _FakeWorkspaceWorkflowRepository
    implements WorkspaceWorkflowRepository {
  new(this.workflow);

  final Workflow workflow;

  @override
  Future<Result<Workflow>> getById(String workspacePath, String id) async =>
      Success(workflow);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late EngineHarness harness;
  late Workflow savedWorkflow;
  late Workflow pinnedWorkflow;
  late RunService service;

  setUp(() {
    harness = EngineHarness();
    savedWorkflow = Workflow(
      id: 'wf-1',
      name: 'Saved Workflow',
      entryNodeId: 'h',
      edges: const <WorkflowEdge>[],
      createdAt: DateTime.utc(2026, 11, 23, 10),
      updatedAt: DateTime.utc(2026, 11, 23, 10),
      nodes: const [
        WorkflowNode(
          id: 'h',
          type: NodeTypeId.claudeCode,
          label: 'Code',
          position: WorkflowPosition(x: 0, y: 0),
          config: <String, Object?>{'prompt': 'saved'},
        ),
      ],
    );
    pinnedWorkflow = savedWorkflow.copyWith(name: 'Pinned Workflow');
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

  tearDown(() async {
    await service.waitForActiveExecutions();
  });

  test(
    'startChildRun stores the parent link, input and pinned definition',
    () async {
      final res = await service.startChildRun(
        ChildRunRequest(
          parentRunId: 'parent-1',
          parentNodeId: 'fan-1',
          index: 2,
          name: 'Item 3',
          workflow: pinnedWorkflow,
          workspaceId: 'ws-1',
          placement: ChildRunPlacement.lentFolder,
          input: 'child-input',
        ),
      );

      final run = res.valueOrNull!;
      expect(run.workflowDefinition, pinnedWorkflow);
      expect(run.parentRunId, 'parent-1');
      expect(run.parentNodeId, 'fan-1');
      expect(run.childIndex, 2);
      expect(run.childName, 'Item 3');
      expect(run.input, 'child-input');
      expect(harness.runs.runs[run.id], run);
    },
  );

  test(
    'node overrides are validated and applied; invalid ones create no run',
    () async {
      final res = await service.startChildRun(
        ChildRunRequest(
          parentRunId: 'parent-1',
          parentNodeId: 'fan-1',
          index: 0,
          name: 'Item 1',
          workflow: pinnedWorkflow,
          workspaceId: 'ws-1',
          placement: ChildRunPlacement.lentFolder,
          nodeOverrides: const {'missing-node': NodeOverride(model: 'm1')},
        ),
      );

      expect(res.failureOrNull, isA<ValidationFailure>());
      expect(harness.runs.runs, isEmpty);
    },
  );

  test(
    'lent folder child starts while the parent is active in the same folder',
    () async {
      await harness.runs.create(
        Run(
          id: 'parent-1',
          workflowId: 'wf-1',
          workflowName: 'Parent',
          workflowDefinition: savedWorkflow,
          workspacePath: '.',
          workspaceId: 'ws-1',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026),
        ),
      );

      final childRes = await service.startChildRun(
        ChildRunRequest(
          parentRunId: 'parent-1',
          parentNodeId: 'fan-1',
          index: 0,
          name: 'Item 1',
          workflow: pinnedWorkflow,
          workspaceId: 'ws-1',
          placement: ChildRunPlacement.lentFolder,
        ),
      );
      expect(childRes.isSuccess, isTrue);
      expect(
        childRes.valueOrNull!.isolationMode,
        WorkspaceIsolationMode.direct,
      );
      expect(childRes.valueOrNull!.worktreePath, isNull);

      final plainRes = await service.startRun(
        const StartRunRequest(workflowId: 'wf-1', workspaceId: 'ws-1'),
      );
      expect(plainRes.failureOrNull, isA<ConflictFailure>());
    },
  );

  test('inspectParentWorkspace is not git for a non-git workspace', () async {
    await harness.runs.create(
      Run(
        id: 'parent-1',
        workflowId: 'wf-1',
        workflowName: 'Parent',
        workflowDefinition: savedWorkflow,
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
      ),
    );

    final res = await service.inspectParentWorkspace(runId: 'parent-1');
    expect(res.valueOrNull!.isGit, isFalse);
  });

  test('finalOutputOf returns last node output, or null if none', () async {
    expect((await service.finalOutputOf('r-none')).valueOrNull, isNull);

    await harness.checkpoints.append(
      id: 'cp-1',
      runId: 'r-1',
      completedNodeId: 'n1',
      pendingNodeIds: const [],
      attemptsByEdge: const {},
      circuitBreakerCount: 0,
      nodeOutputs: const {
        'n1': {
          'outputLabel': 'onSuccess',
          'data': {'ok': true},
        },
      },
      createdAt: DateTime.utc(2026),
    );

    final res = await service.finalOutputOf('r-1');
    expect(res.valueOrNull, {
      'outputLabel': 'onSuccess',
      'data': {'ok': true},
    });
  });

  test('recordWarning appends snapshot.warning with source fan_out', () async {
    await service.recordWarning(
      runId: 'parent-1',
      nodeId: 'fan-1',
      message: 'Empty list',
    );

    final events = harness.events.events
        .where((e) => e.runId == 'parent-1')
        .toList();
    expect(events, hasLength(1));
    expect(events.single.type, RunEventType.snapshotWarning);
    expect(events.single.nodeId, 'fan-1');
    expect(events.single.payload, {
      'message': 'Empty list',
      'source': 'fan_out',
    });
  });

  test('paused lent child resumes while parent runs in same folder', () async {
    await harness.runs.create(
      Run(
        id: 'parent-1',
        workflowId: 'wf-1',
        workflowName: 'Parent',
        workflowDefinition: savedWorkflow,
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026),
      ),
    );
    await harness.runs.create(
      Run(
        id: 'child-1',
        workflowId: 'wf-1',
        workflowName: 'Child',
        workflowDefinition: pinnedWorkflow,
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.interrupted,
        startedAt: DateTime.utc(2026),
        parentRunId: 'parent-1',
        parentNodeId: 'fan-1',
        childIndex: 0,
        childName: 'Item 1',
      ),
    );

    final res = await service.resumeRun('child-1');
    expect(res.failureOrNull, isNot(isA<ConflictFailure>()));

    await harness.runs.create(
      Run(
        id: 'other-1',
        workflowId: 'wf-1',
        workflowName: 'Other',
        workflowDefinition: savedWorkflow,
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.interrupted,
        startedAt: DateTime.utc(2026),
      ),
    );
    final otherRes = await service.resumeRun('other-1');
    expect(otherRes.failureOrNull, isA<ConflictFailure>());
  });

  test(
    'pinWorkflow resolves the workspace workflow before the global one',
    () async {
      final wsWorkflow = savedWorkflow.copyWith(name: 'Workspace Workflow');
      final scopedService = RunService(
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
        workspaceWorkflows: _FakeWorkspaceWorkflowRepository(wsWorkflow),
        engine: harness.engine,
        workspacePreparation: const WorkspacePreparationService(
          git: GitClient(_FakeProcessRunner()),
        ),
      );

      final res = await scopedService.pinWorkflow(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
      );
      expect(res.valueOrNull!.name, 'Workspace Workflow');
    },
  );

  test('listChildRuns delegates to the repository', () async {
    await harness.runs.create(
      Run(
        id: 'c2',
        workflowId: 'wf-1',
        workflowName: 'Child',
        workflowDefinition: pinnedWorkflow,
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 1, 2),
        parentRunId: 'parent-1',
        parentNodeId: 'fan',
        childIndex: 1,
      ),
    );
    await harness.runs.create(
      Run(
        id: 'c1',
        workflowId: 'wf-1',
        workflowName: 'Child',
        workflowDefinition: pinnedWorkflow,
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 1, 1),
        parentRunId: 'parent-1',
        parentNodeId: 'fan',
        childIndex: 0,
      ),
    );

    final res = await service.listChildRuns(
      parentRunId: 'parent-1',
      parentNodeId: 'fan',
    );
    expect(res.valueOrNull!.map((r) => r.id), ['c1', 'c2']);
  });

  test('resumeChildRun returns ConflictFailure for non-interrupted child', () async {
    await harness.runs.create(
      Run(
        id: 'c-run',
        workflowId: 'wf-1',
        workflowName: 'Child',
        workflowDefinition: pinnedWorkflow,
        workspacePath: '.',
        workspaceId: 'ws-1',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026),
        parentRunId: 'parent-1',
        parentNodeId: 'fan',
      ),
    );

    final res = await service.resumeChildRun('c-run');
    expect(res.failureOrNull, isA<ConflictFailure>());
  });

  test('cancelChildRun cancels through the canceller', () async {
    final cancelled = <String>[];
    final customService = RunService(
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
      canceller: _RecordingCanceller(cancelled),
      workspacePreparation: const WorkspacePreparationService(
        git: GitClient(_FakeProcessRunner()),
      ),
    );

    final res = await customService.cancelChildRun('c-1');
    expect(res.isSuccess, isTrue);
    expect(cancelled, ['c-1']);
  });
}

final class _RecordingCanceller implements RunCanceller {
  _RecordingCanceller(this.cancelled);

  final List<String> cancelled;

  @override
  Future<Result<Run>> cancel(String runId) async {
    cancelled.add(runId);
    return Success(
      Run(
        id: runId,
        workflowId: 'wf-1',
        workflowName: 'Child',
        workflowDefinition: Workflow(
          id: 'wf-1',
          name: 'Child',
          nodes: const [],
          edges: const [],
          entryNodeId: 'n1',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        workspacePath: '.',
        status: RunStatus.cancelled,
        startedAt: DateTime.utc(2026),
      ),
    );
  }
}
