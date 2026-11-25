import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final List<String> calls = <String>[];

  static final DateTime _now = DateTime.utc(2026, 11, 20, 12);

  static final Workflow sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Sample',
    nodes: const <WorkflowNode>[],
    edges: const <WorkflowEdge>[],
    createdAt: _now,
    updatedAt: _now,
  );

  static const WorkflowValidationResult validResult = WorkflowValidationResult(
    isValid: true,
  );

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    String? workspaceId,
  }) async {
    calls.add('list');
    return Success(<WorkflowSummary>[
      WorkflowSummary(
        id: 'wf-1',
        name: 'Sample',
        nodeCount: 0,
        edgeCount: 0,
        hasValidationErrors: false,
        updatedAt: _now,
      ),
    ]);
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) async {
    calls.add('get:$id');
    return Success(
      WorkflowResponse(workflow: sampleWorkflow, validation: validResult),
    );
  }

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async {
    calls.add('create:${request.name}');
    return Success(
      WorkflowResponse(
        workflow: sampleWorkflow.copyWith(name: request.name),
        validation: validResult,
      ),
    );
  }

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) async {
    calls.add('update:$id:${request.name}');
    return Success(
      WorkflowResponse(
        workflow: sampleWorkflow.copyWith(id: id, name: request.name),
        validation: validResult,
      ),
    );
  }

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async {
    calls.add('duplicate:$id:$name');
    return Success(
      WorkflowResponse(
        workflow: sampleWorkflow.copyWith(
          id: 'wf-2',
          name: name ?? 'Sample Copy',
        ),
        validation: validResult,
      ),
    );
  }

  String? lastDeleteRevision;
  bool? lastDeleteForce;

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    String? workspaceId,
    String? revision,
    bool force = false,
  }) {
    calls.add('delete:$id');
    lastDeleteRevision = revision;
    lastDeleteForce = force;
    return Stream.value(const WorkflowDeletionSucceeded());
  }

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async {
    calls.add('validate:${workflow.id}');
    return const Success(validResult);
  }
}

void main() {
  group('Workflow use cases and DI providers', () {
    test('DeleteWorkflow forwards force and revision', () async {
      final repo = _FakeWorkflowRepository();
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final updates = await container
          .read(deleteWorkflowProvider)
          .call('wf-1', revision: 'r1', force: true)
          .toList();

      expect(updates, [isA<WorkflowDeletionSucceeded>()]);
      expect(repo.lastDeleteRevision, 'r1');
      expect(repo.lastDeleteForce, isTrue);
    });

    test(
      'all use cases delegate to WorkflowRepository via Riverpod DI',
      () async {
        final repo = _FakeWorkflowRepository();
        final container = ProviderContainer.test(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        );

        final listResult = await container.read(listWorkflowsProvider).call();
        expect(listResult.valueOrNull, hasLength(1));

        final getResult = await container
            .read(getWorkflowProvider)
            .call('wf-1');
        expect(getResult.valueOrNull?.workflow.id, 'wf-1');

        final createResult = await container
            .read(createWorkflowProvider)
            .call(const CreateWorkflowRequest(name: 'New Flow'));
        expect(createResult.valueOrNull?.workflow.name, 'New Flow');

        final updateResult = await container
            .read(updateWorkflowProvider)
            .call('wf-1', const UpdateWorkflowRequest(name: 'Updated Flow'));
        expect(updateResult.valueOrNull?.workflow.name, 'Updated Flow');

        final dupResult = await container
            .read(duplicateWorkflowProvider)
            .call('wf-1', name: 'Clone');
        expect(dupResult.valueOrNull?.workflow.id, 'wf-2');

        final delUpdates = await container
            .read(deleteWorkflowProvider)
            .call('wf-1')
            .toList();
        expect(delUpdates, [isA<WorkflowDeletionSucceeded>()]);

        final valResult = await container
            .read(validateWorkflowProvider)
            .call(_FakeWorkflowRepository.sampleWorkflow);
        expect(valResult.valueOrNull?.isValid, isTrue);

        expect(repo.calls, <String>[
          'list',
          'get:wf-1',
          'create:New Flow',
          'update:wf-1:Updated Flow',
          'duplicate:wf-1:Clone',
          'delete:wf-1',
          'validate:wf-1',
        ]);
      },
    );
  });
}
