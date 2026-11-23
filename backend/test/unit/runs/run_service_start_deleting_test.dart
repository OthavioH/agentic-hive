import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../engine/support/engine_harness.dart';
import '../engine/support/in_memory_repositories.dart';

final class _FakeProcessRunner implements ProcessRunner {
  const _FakeProcessRunner();

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
  _SingleWorkflowRepository(this.workflow, {required this.onGet});

  final Workflow workflow;
  final void Function() onGet;

  @override
  Future<Result<Workflow>> getById(String id) async {
    onGet();
    return Success(workflow);
  }

  @override
  Future<Result<Workflow>> get(String id, {String? workspaceId}) async {
    onGet();
    return Success(workflow);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkflowDeletionOperation op(
  String id,
  String workflowId, {
  String? workspaceId,
}) => WorkflowDeletionOperation(
  id: id,
  workflowId: workflowId,
  workspaceId: workspaceId,
  phase: WorkflowDeletionPhase.deletingRuns,
  startedAt: DateTime.utc(2026, 11, 23, 10),
);

void main() {
  late WorkflowDeletionRegistry registry;
  late RunService service;

  setUp(() {
    registry = WorkflowDeletionRegistry();
    service = RunService(
      runs: InMemoryRunRepository(),
      checkpoints: InMemoryCheckpointRepository(),
      events: InMemoryRunEventRepository(),
      deletions: registry,
    );
  });

  StartRunRequest request({
    String workflowId = 'wf-1',
    String workspaceId = 'ws-1',
  }) => StartRunRequest(workflowId: workflowId, workspaceId: workspaceId);

  test('startRun refuses with WorkflowDeletingFailure while the workflow is '
      'being deleted', () async {
    registry.start(op('op-1', 'wf-1', workspaceId: 'ws-1'));

    final result = await service.startRun(request());

    final failure = result.failureOrNull! as WorkflowDeletingFailure;
    expect(failure.operationId, 'op-1');
    expect(failure.message, 'Workflow "wf-1" is being deleted.');
  });

  test('startRun refuses while the global workflow with that id is being '
      'deleted', () async {
    registry.start(op('op-2', 'wf-1'));

    final result = await service.startRun(request());

    final failure = result.failureOrNull! as WorkflowDeletingFailure;
    expect(failure.operationId, 'op-2');
  });

  test('startRun passes the guard when nothing is being deleted', () async {
    final result = await service.startRun(request());

    final failure = result.failureOrNull!;
    expect(failure, isA<UnexpectedFailure>());
    expect(failure.message, 'Workspace registry is not configured.');
  });

  test('startRun passes the guard after the operation finished', () async {
    registry
      ..start(op('op-1', 'wf-1', workspaceId: 'ws-1'))
      ..update(
        'op-1',
        (current) => current.copyWith(
          phase: WorkflowDeletionPhase.done,
          outcome: WorkflowDeletionOutcome.deleted,
        ),
      );

    final result = await service.startRun(request());

    expect(result.failureOrNull, isNot(isA<WorkflowDeletingFailure>()));
  });

  test(
    'startRun refuses with WorkflowDeletingFailure when deletion starts '
    'between initial check and run creation',
    () async {
      final harness = EngineHarness();
      final runs = harness.runs;
      final gatedService = RunService(
        runs: runs,
        checkpoints: harness.checkpoints,
        events: harness.events,
        workspaces: WorkspaceService(
          workspaces: _FakeWorkspaceRepository(),
          capabilities: const WorkspaceCapabilitiesService(
            GitClient(_FakeProcessRunner()),
          ),
        ),
        workflows: _SingleWorkflowRepository(
          Workflow(
            id: 'wf-1',
            name: 'Deploy',
            nodes: const [
              WorkflowNode(
                id: 'n1',
                type: 'start',
                label: 'Start',
                position: WorkflowPosition(x: 0, y: 0),
              ),
            ],
            edges: const [],
            createdAt: DateTime.utc(2026, 11, 23, 10),
            updatedAt: DateTime.utc(2026, 11, 23, 10),
          ),
          onGet: () => registry.start(op('op-race', 'wf-1', workspaceId: 'ws-1')),
        ),
        engine: harness.engine,
        workspacePreparation: WorkspacePreparationService(
          git: const GitClient(_FakeProcessRunner()),
        ),
        deletions: registry,
      );

      final result = await gatedService.startRun(request());

      final failure = result.failureOrNull! as WorkflowDeletingFailure;
      expect(failure.operationId, 'op-race');
      expect((await runs.list()).valueOrNull!.items, isEmpty);
    },
  );
}
