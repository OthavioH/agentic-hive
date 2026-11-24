import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_runs_deleter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final store = <String, Workflow>{};

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (store.remove(id) == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Workflow>> getById(String id) async {
    final workflow = store[id];
    if (workflow == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return Success(workflow);
  }

  @override
  Future<Result<List<Workflow>>> listAll() async =>
      Success(store.values.toList());

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }
}

final class _GatedRunsDeleter implements WorkflowRunsDeleter {
  Map<String, RunStatus> activeRuns = {};
  Completer<void>? gate;

  @override
  Future<Result<Map<String, RunStatus>>> activeRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
  }) async => Success(activeRuns);

  @override
  Future<Result<WorkflowRunsDeletion>> deleteRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
    bool force = false,
    WorkflowRunsProgressListener? onProgress,
  }) async {
    await gate?.future;
    return const Success(WorkflowRunsDeletion(deletedRuns: 0));
  }
}

Workflow _plainWorkflow(String id, String name) => Workflow(
  id: id,
  name: name,
  nodes: const [
    WorkflowNode(
      id: 'n1',
      type: 'harness',
      label: 'Step',
      position: WorkflowPosition(x: 0, y: 0),
    ),
  ],
  edges: const [],
  entryNodeId: 'n1',
  createdAt: DateTime.utc(2026, 11, 23, 10),
  updatedAt: DateTime.utc(2026, 11, 23, 10),
);

Workflow _fanOutWorkflow(String id, String name, String targetId) => Workflow(
  id: id,
  name: name,
  nodes: [
    WorkflowNode(
      id: 'fan-1',
      type: NodeTypeId.fanOut,
      label: 'Fan-out',
      position: const WorkflowPosition(x: 0, y: 0),
      config: {'workflowId': targetId},
    ),
  ],
  edges: const [],
  entryNodeId: 'fan-1',
  createdAt: DateTime.utc(2026, 11, 23, 10),
  updatedAt: DateTime.utc(2026, 11, 23, 10),
);

void main() {
  late _FakeWorkflowRepository repository;
  late _GatedRunsDeleter deleter;
  late WorkflowDeletionRegistry registry;
  late WorkflowService service;
  late int counter;

  setUp(() {
    repository = _FakeWorkflowRepository();
    deleter = _GatedRunsDeleter();
    registry = WorkflowDeletionRegistry();
    counter = 0;
    service = WorkflowService(
      repository: repository,
      validator: const WorkflowValidator(),
      runsDeleter: deleter,
      deletions: registry,
      generateId: () => 'op-${++counter}',
      now: () => DateTime.utc(2026, 11, 23, 10),
    );
  });

  test('getReferences returns NotFound for an unknown workflow', () async {
    final res = await service.getReferences('missing');
    expect(res.failureOrNull, isA<NotFoundFailure>());
  });

  test('getReferences lists referencing workflows', () async {
    repository.store['wf-child'] = _plainWorkflow('wf-child', 'Child');
    repository.store['wf-parent'] = _fanOutWorkflow(
      'wf-parent',
      'Parent',
      'wf-child',
    );

    final res = await service.getReferences('wf-child');
    expect(res.valueOrNull!.references, [
      const WorkflowReference(
        workflowId: 'wf-parent',
        workflowName: 'Parent',
        scope: WorkflowScope.global,
        nodeIds: ['fan-1'],
      ),
    ]);
  });

  test(
    'deleteWorkflow accepted answer carries references and joining a running '
    'operation answers empty references',
    () async {
      repository.store['wf-child'] = _plainWorkflow('wf-child', 'Child');
      repository.store['wf-parent'] = _fanOutWorkflow(
        'wf-parent',
        'Parent',
        'wf-child',
      );
      deleter.gate = Completer<void>();

      final first = await service.deleteWorkflow('wf-child');
      expect(first.valueOrNull!.references, hasLength(1));
      expect(first.valueOrNull!.references.first.workflowId, 'wf-parent');

      final second = await service.deleteWorkflow('wf-child');
      expect(second.valueOrNull!.operationId, first.valueOrNull!.operationId);
      expect(second.valueOrNull!.references, isEmpty);

      deleter.gate!.complete();
    },
  );

  test('references do not block the delete', () async {
    repository.store['wf-child'] = _plainWorkflow('wf-child', 'Child');
    repository.store['wf-parent'] = _fanOutWorkflow(
      'wf-parent',
      'Parent',
      'wf-child',
    );

    final accepted = await service.deleteWorkflow('wf-child');
    expect(accepted.isSuccess, isTrue);

    await Future<void>.delayed(Duration.zero);
    final op = registry.byId(accepted.valueOrNull!.operationId)!;
    expect(op.outcome, WorkflowDeletionOutcome.deleted);
    expect(repository.store.containsKey('wf-child'), isFalse);
  });

  test('deleteWorkflow without force fails with WorkflowHasActiveRunsFailure '
      'when only a child is active', () async {
    repository.store['wf-parent'] = _plainWorkflow('wf-parent', 'Parent');
    deleter.activeRuns = {'c1': RunStatus.running};

    final res = await service.deleteWorkflow('wf-parent');
    final failure = res.failureOrNull! as WorkflowHasActiveRunsFailure;
    expect(failure.activeRuns.keys, ['c1']);
  });
}
