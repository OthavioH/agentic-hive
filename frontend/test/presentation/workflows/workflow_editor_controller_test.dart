import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 20, 12);
  int validateCalls = 0;
  int updateCalls = 0;
  String revision = 'rev-1';
  String? lastRequestRevision;
  Result<WorkflowResponse>? saveOverride;

  WorkflowValidationResult nextValidation = const WorkflowValidationResult(
    isValid: true,
  );

  Workflow stored = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    description: 'Initial',
    nodes: const <WorkflowNode>[],
    edges: const <WorkflowEdge>[],
    createdAt: DateTime.utc(2026, 11, 20, 12),
    updatedAt: DateTime.utc(2026, 11, 20, 12),
  );

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) async {
    return Success(
      WorkflowResponse(
        workflow: stored,
        validation: nextValidation,
        revision: revision,
      ),
    );
  }

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) async {
    updateCalls++;
    lastRequestRevision = request.revision;
    if (saveOverride != null) return saveOverride!;
    stored = stored.copyWith(
      name: request.name,
      description: request.description,
      nodes: request.nodes,
      edges: request.edges,
      entryNodeId: request.entryNodeId,
    );
    revision = 'rev-${updateCalls + 1}';
    return Success(
      WorkflowResponse(
        workflow: stored,
        validation: nextValidation,
        revision: revision,
      ),
    );
  }

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async {
    validateCalls++;
    return Success(nextValidation);
  }

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    String? workspaceId,
  }) async => const Success(<WorkflowSummary>[]);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteWorkflow(String id, {String? workspaceId}) async =>
      const Success<void>(null);
}

void main() {
  group('WorkflowEditorController', () {
    test(
      'first node becomes entryNodeId automatically and marks dirty',
      () async {
        final repo = _FakeWorkflowRepository();
        final container = ProviderContainer.test(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        );

        final provider = workflowEditorControllerProvider('wf-1');
        final initial = await container.read(provider.future);
        expect(initial.isDirty, isFalse);
        expect(initial.workflow.entryNodeId, isNull);

        final notifier = container.read(provider.notifier)
          ..addNode(typeId: NodeTypeId.command, defaultLabel: 'Step 1');
        final afterFirst = container.read(provider).requireValue;
        expect(afterFirst.isDirty, isTrue);
        expect(afterFirst.workflow.nodes, hasLength(1));
        final firstNode = afterFirst.workflow.nodes.first;
        expect(firstNode.type, NodeTypeId.command);
        expect(firstNode.config, NodeDescriptors.command.defaultConfig());
        final firstId = firstNode.id;
        expect(afterFirst.workflow.entryNodeId, firstId);
        expect(afterFirst.selectedNodeId, firstId);

        notifier.addNode(
          typeId: NodeTypeId.humanApproval,
          defaultLabel: 'Step 2',
        );
        final afterSecond = container.read(provider).requireValue;
        expect(afterSecond.workflow.nodes, hasLength(2));
        expect(afterSecond.workflow.entryNodeId, firstId);
      },
    );

    test(
      'updateNodeConfig updates node config and triggers revalidation',
      () async {
        final repo = _FakeWorkflowRepository();
        final container = ProviderContainer.test(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        );

        final provider = workflowEditorControllerProvider('wf-1');
        await container.read(provider.future);
        final notifier = container.read(provider.notifier)
          ..addNode(typeId: NodeTypeId.command, defaultLabel: 'Run Tests');
        final nodeId = container
            .read(provider)
            .requireValue
            .workflow
            .nodes
            .first
            .id;
        final callsBefore = repo.validateCalls;

        final updatedConfig = const CommandNodeConfig(
          command: 'dart',
          args: <String>['test'],
        ).toJson();
        notifier.updateNodeConfig(nodeId, updatedConfig);

        final state = container.read(provider).requireValue;
        expect(state.workflow.nodes.first.config, updatedConfig);
        expect(state.isDirty, isTrue);
        expect(repo.validateCalls, greaterThan(callsBefore));
      },
    );

    test('edge creation, update, and node deletion cascade', () async {
      final repo = _FakeWorkflowRepository();
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final provider = workflowEditorControllerProvider('wf-1');
      await container.read(provider.future);
      final notifier = container.read(provider.notifier)
        ..addNode(typeId: NodeTypeId.command, defaultLabel: 'A')
        ..addNode(typeId: NodeTypeId.command, defaultLabel: 'B');

      final nodes = container.read(provider).requireValue.workflow.nodes;
      notifier.addEdge(sourceNodeId: nodes[0].id, targetNodeId: nodes[1].id);
      var state = container.read(provider).requireValue;
      expect(state.workflow.edges, hasLength(1));
      final edgeId = state.workflow.edges.first.id;
      expect(state.selectedEdgeId, edgeId);

      notifier.updateEdge(edgeId, sourceOutput: 'onFailure', maxRetries: 2);
      state = container.read(provider).requireValue;
      expect(state.workflow.edges.first.sourceOutput, 'onFailure');
      expect(state.workflow.edges.first.maxRetries, 2);

      // Deleting source node removes connected edge and clears entryNodeId.
      notifier.deleteNode(nodes[0].id);
      state = container.read(provider).requireValue;
      expect(state.workflow.nodes, hasLength(1));
      expect(state.workflow.edges, isEmpty);
      expect(state.workflow.entryNodeId, isNull);
    });

    test(
      'focusIssue selects target node and emits EditorFocusRequest',
      () async {
        final repo = _FakeWorkflowRepository();
        final container = ProviderContainer.test(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        );

        final provider = workflowEditorControllerProvider('wf-1');
        await container.read(provider.future);
        final notifier = container.read(provider.notifier)
          ..addNode(
            typeId: NodeTypeId.command,
            defaultLabel: 'Step 1',
            x: 300,
            y: 400,
          );
        final nodeId = container
            .read(provider)
            .requireValue
            .workflow
            .nodes
            .first
            .id;

        notifier
          ..clearSelection()
          ..focusIssue(
            WorkflowValidationIssue(
              severity: WorkflowValidationSeverity.error,
              code: 'invalid',
              message: 'Broken node',
              nodeId: nodeId,
            ),
          );

        final state = container.read(provider).requireValue;
        expect(state.selectedNodeId, nodeId);
        expect(state.focusRequest, isNotNull);
        expect(state.focusRequest!.x, greaterThan(300));
      },
    );

    test('save persists workflow and resets isDirty', () async {
      final repo = _FakeWorkflowRepository();
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final provider = workflowEditorControllerProvider('wf-1');
      await container.read(provider.future);
      final notifier = container.read(provider.notifier)
        ..addNode(typeId: NodeTypeId.command, defaultLabel: 'Step 1')
        ..updateWorkflowMetadata(name: 'Renamed Flow');

      expect(container.read(provider).requireValue.isDirty, isTrue);

      final saveResult = await notifier.save();
      expect(saveResult.isSuccess, isTrue);
      expect(repo.updateCalls, 1);

      final savedState = container.read(provider).requireValue;
      expect(savedState.isDirty, isFalse);
      expect(savedState.workflow.name, 'Renamed Flow');
    });

    test('save sends the loaded revision and stores the new one', () async {
      final repo = _FakeWorkflowRepository();
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final provider = workflowEditorControllerProvider('wf-1');
      await container.read(provider.future);
      final notifier = container.read(provider.notifier)
        ..updateWorkflowMetadata(name: 'First Edit');

      await notifier.save();
      expect(repo.lastRequestRevision, 'rev-1');
      expect(container.read(provider).requireValue.revision, 'rev-2');

      notifier.updateWorkflowMetadata(name: 'Second Edit');
      await notifier.save();
      expect(repo.lastRequestRevision, 'rev-2');
    });

    test(
      'save conflict exposes hasRevisionConflict and keeps the draft',
      () async {
        final repo = _FakeWorkflowRepository();
        final container = ProviderContainer.test(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        );

        final provider = workflowEditorControllerProvider('wf-1');
        await container.read(provider.future);
        final notifier = container.read(provider.notifier)
          ..updateWorkflowMetadata(name: 'Draft');
        repo.saveOverride = const FailureResult(
          BackendFailure(
            'changed',
            code: ApiErrorCode.revisionConflict,
            statusCode: 409,
          ),
        );

        await notifier.save();
        final state = container.read(provider).requireValue;
        expect(state.hasRevisionConflict, isTrue);
        expect(state.isDirty, isTrue);
        expect(state.isSaving, isFalse);
      },
    );

    test('a generic 409 is not a revision conflict', () async {
      final repo = _FakeWorkflowRepository();
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final provider = workflowEditorControllerProvider('wf-1');
      await container.read(provider.future);
      final notifier = container.read(provider.notifier)
        ..updateWorkflowMetadata(name: 'Draft');
      repo.saveOverride = const FailureResult(
        BackendFailure('x', code: ApiErrorCode.conflict, statusCode: 409),
      );

      await notifier.save();
      expect(
        container.read(provider).requireValue.hasRevisionConflict,
        isFalse,
      );
    });

    test('reload discards the draft and loads the latest workflow', () async {
      final repo = _FakeWorkflowRepository();
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final provider = workflowEditorControllerProvider('wf-1');
      await container.read(provider.future);
      final notifier = container.read(provider.notifier)
        ..updateWorkflowMetadata(name: 'Draft');
      repo.saveOverride = const FailureResult(
        BackendFailure(
          'changed',
          code: ApiErrorCode.revisionConflict,
          statusCode: 409,
        ),
      );
      await notifier.save();

      repo
        ..stored = repo.stored.copyWith(name: 'Remote')
        ..revision = 'rev-9'
        ..saveOverride = null;

      notifier.reload();
      final reloaded = await container.read(provider.future);
      expect(reloaded.workflow.name, 'Remote');
      expect(reloaded.revision, 'rev-9');
      expect(reloaded.isDirty, isFalse);
      expect(reloaded.saveFailure, isNull);
    });
  });
}
