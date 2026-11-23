import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final _store = <String, Workflow>{};
  Duration? updateDelay;

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    _store[workflow.id] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (_store.remove(id) == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Workflow>> getById(String id) async {
    final wf = _store[id];
    if (wf == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return Success(wf);
  }

  @override
  Future<Result<List<Workflow>>> listAll() async {
    final items = _store.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Success(items);
  }

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    if (updateDelay != null) {
      await Future<void>.delayed(updateDelay!);
    }
    if (!_store.containsKey(workflow.id)) {
      return FailureResult(
        NotFoundFailure('Workflow "${workflow.id}" not found.'),
      );
    }
    _store[workflow.id] = workflow;
    return Success(workflow);
  }
}

void main() {
  late _FakeWorkflowRepository repository;
  late DateTime currentTime;
  late int idSeq;
  late WorkflowService service;

  setUp(() {
    repository = _FakeWorkflowRepository();
    currentTime = DateTime.utc(2026, 11, 20, 12);
    idSeq = 0;
    service = WorkflowService(
      repository: repository,
      validator: const WorkflowValidator(),
      generateId: () => 'wf-${++idSeq}',
      now: () => currentTime,
    );
  });

  test(
    'createWorkflow persists invalid draft and returns validation issues',
    () async {
      final result = await service.createWorkflow(
        const CreateWorkflowRequest(name: ''),
      );

      final response = result.valueOrNull!;
      expect(response.workflow.id, 'wf-1');
      expect(response.validation.isValid, isFalse);
      expect(response.validation.issues, isNotEmpty);
    },
  );

  test(
    'listWorkflows computes summary counts and hasValidationErrors',
    () async {
      await service.createWorkflow(const CreateWorkflowRequest(name: 'Draft'));
      currentTime = currentTime.add(const Duration(minutes: 5));
      await service.createWorkflow(
        const CreateWorkflowRequest(
          name: 'Valid',
          nodes: [
            WorkflowNode(
              id: 'n1',
              type: NodeTypeId.command,
              label: 'Start',
              position: WorkflowPosition(x: 0, y: 0),
              config: {'command': 'echo start'},
            ),
          ],
          entryNodeId: 'n1',
        ),
      );

      final list = (await service.listWorkflows()).valueOrNull!;
      expect(list.workflows, hasLength(2));
      expect(list.workflows.first.name, 'Valid');
      expect(list.workflows.first.hasValidationErrors, isFalse);
      expect(list.workflows.first.nodeCount, 1);
      expect(list.workflows.last.name, 'Draft');
      expect(list.workflows.last.hasValidationErrors, isTrue);
    },
  );

  test('updateWorkflow preserves createdAt and refreshes updatedAt', () async {
    final created = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Initial'),
    )).valueOrNull!.workflow;

    currentTime = currentTime.add(const Duration(hours: 1));
    final updated = (await service.updateWorkflow(
      created.id,
      const UpdateWorkflowRequest(
        name: 'Renamed',
        nodes: [
          WorkflowNode(
            id: 'n1',
            type: NodeTypeId.command,
            label: 'Step',
            position: WorkflowPosition(x: 10, y: 20),
            config: {'command': 'echo step'},
          ),
        ],
        entryNodeId: 'n1',
      ),
    )).valueOrNull!;

    expect(updated.workflow.createdAt, created.createdAt);
    expect(updated.workflow.updatedAt, currentTime);
    expect(updated.workflow.name, 'Renamed');
    expect(updated.validation.isValid, isTrue);
  });

  test('duplicateWorkflow clones graph with a new id and copy name', () async {
    final created = (await service.createWorkflow(
      const CreateWorkflowRequest(
        name: 'Original',
        description: 'Desc',
        nodes: [
          WorkflowNode(
            id: 'n1',
            type: NodeTypeId.command,
            label: 'Step 1',
            position: WorkflowPosition(x: 10, y: 20),
            config: {'command': 'echo step1'},
          ),
        ],
        entryNodeId: 'n1',
      ),
    )).valueOrNull!.workflow;

    currentTime = currentTime.add(const Duration(minutes: 10));
    final duplicated = (await service.duplicateWorkflow(created.id))
        .valueOrNull!;

    expect(duplicated.workflow.id, isNot(created.id));
    expect(duplicated.workflow.name, 'Original (Copy)');
    expect(duplicated.workflow.description, 'Desc');
    expect(duplicated.workflow.nodes, created.nodes);
    expect(duplicated.workflow.entryNodeId, 'n1');
  });

  test('getWorkflow returns NotFoundFailure for unknown id', () async {
    final result = await service.getWorkflow('missing');

    expect(result.failureOrNull, isA<NotFoundFailure>());
  });

  test('getWorkflow returns the revision of the stored workflow', () async {
    final created = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Initial'),
    )).valueOrNull!.workflow;

    final fetched = (await service.getWorkflow(created.id)).valueOrNull!;
    expect(fetched.revision, workflowRevision(fetched.workflow));
  });

  test('listWorkflows summaries carry the revision', () async {
    final created = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'One'),
    )).valueOrNull!.workflow;

    final list = (await service.listWorkflows()).valueOrNull!;
    expect(list.workflows.single.revision, workflowRevision(created));
  });

  test(
    'create, update and duplicate responses carry the new revision',
    () async {
      final created = (await service.createWorkflow(
        const CreateWorkflowRequest(name: 'One'),
      )).valueOrNull!;
      expect(created.revision, isNotNull);
      expect(created.revision, workflowRevision(created.workflow));

      final updated = (await service.updateWorkflow(
        created.workflow.id,
        const UpdateWorkflowRequest(name: 'Two'),
      )).valueOrNull!;
      expect(updated.revision, isNotNull);
      expect(updated.revision, workflowRevision(updated.workflow));
      expect(updated.revision, isNot(created.revision));

      final duplicated = (await service.duplicateWorkflow(created.workflow.id))
          .valueOrNull!;
      expect(duplicated.revision, isNotNull);
      expect(duplicated.revision, workflowRevision(duplicated.workflow));
    },
  );

  test('updateWorkflow with the current revision succeeds', () async {
    final created = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'One'),
    )).valueOrNull!;

    final updated = await service.updateWorkflow(
      created.workflow.id,
      UpdateWorkflowRequest(name: 'Two', revision: created.revision),
    );
    expect(updated.valueOrNull!.workflow.name, 'Two');
  });

  test(
    'updateWorkflow with a stale revision fails with StaleRevisionFailure and '
    'writes nothing',
    () async {
      final created = (await service.createWorkflow(
        const CreateWorkflowRequest(name: 'One'),
      )).valueOrNull!;
      final r0 = created.revision!;

      final firstUpdate = (await service.updateWorkflow(
        created.workflow.id,
        UpdateWorkflowRequest(name: 'Two', revision: r0),
      )).valueOrNull!;

      final staleResult = await service.updateWorkflow(
        created.workflow.id,
        UpdateWorkflowRequest(name: 'Three', revision: r0),
      );
      expect(staleResult, isA<FailureResult<WorkflowResponse>>());
      final failure = staleResult.failureOrNull! as StaleRevisionFailure;
      expect(failure.currentRevision, firstUpdate.revision);
      expect(
        failure.message,
        'Workflow "${created.workflow.id}" changed since it was read. '
        'Read it again and reapply your change.',
      );

      final stored = (await service.getWorkflow(created.workflow.id))
          .valueOrNull!;
      expect(stored.workflow.name, 'Two');
    },
  );

  test('updateWorkflow without a revision keeps the old behaviour', () async {
    final created = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'One'),
    )).valueOrNull!;

    final withNull = await service.updateWorkflow(
      created.workflow.id,
      const UpdateWorkflowRequest(name: 'Two'),
    );
    expect(withNull, isA<Success<WorkflowResponse>>());

    final withBlank = await service.updateWorkflow(
      created.workflow.id,
      const UpdateWorkflowRequest(name: 'Three', revision: '  '),
    );
    expect(withBlank, isA<Success<WorkflowResponse>>());
  });

  test(
    'deleteWorkflow with a stale revision fails and keeps the workflow',
    () async {
      final created = (await service.createWorkflow(
        const CreateWorkflowRequest(name: 'One'),
      )).valueOrNull!;

      final result = await service.deleteWorkflow(
        created.workflow.id,
        expectedRevision: '0000000000000000',
      );
      expect(result.failureOrNull, isA<StaleRevisionFailure>());
      expect(
        await service.getWorkflow(created.workflow.id),
        isA<Success<WorkflowResponse>>(),
      );
    },
  );

  test('deleteWorkflow with the current revision deletes', () async {
    final created = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'One'),
    )).valueOrNull!;

    final result = await service.deleteWorkflow(
      created.workflow.id,
      expectedRevision: created.revision,
    );
    expect(result, isA<Success<void>>());
    expect(
      (await service.getWorkflow(created.workflow.id)).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('deleteWorkflow without a revision deletes', () async {
    final created = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'One'),
    )).valueOrNull!;

    final result = await service.deleteWorkflow(created.workflow.id);
    expect(result, isA<Success<void>>());
  });

  test(
    'concurrent updates with the same revision: exactly one succeeds',
    () async {
      final created = (await service.createWorkflow(
        const CreateWorkflowRequest(name: 'One'),
      )).valueOrNull!;
      final r0 = created.revision!;

      repository.updateDelay = const Duration(milliseconds: 20);
      final results = await Future.wait([
        service.updateWorkflow(
          created.workflow.id,
          UpdateWorkflowRequest(name: 'First', revision: r0),
        ),
        service.updateWorkflow(
          created.workflow.id,
          UpdateWorkflowRequest(name: 'Second', revision: r0),
        ),
      ]);

      expect(results.whereType<Success<WorkflowResponse>>(), hasLength(1));
      expect(
        results.whereType<FailureResult<WorkflowResponse>>().single.failure,
        isA<StaleRevisionFailure>(),
      );
    },
  );
}
