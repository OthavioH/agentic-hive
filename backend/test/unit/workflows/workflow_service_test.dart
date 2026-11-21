import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final _store = <String, Workflow>{};

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
              type: 'placeholder',
              label: 'Start',
              position: WorkflowPosition(x: 0, y: 0),
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
            type: 'placeholder',
            label: 'Step',
            position: WorkflowPosition(x: 10, y: 20),
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
            type: 'placeholder',
            label: 'Step 1',
            position: WorkflowPosition(x: 10, y: 20),
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
}
