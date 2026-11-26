import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
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
  UpdateWorkflowRequest? lastUpdateRequest;
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
    DefinitionScope scope = const GlobalScope(),
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
    DefinitionScope scope = const GlobalScope(),
  }) async {
    updateCalls++;
    lastRequestRevision = request.revision;
    lastUpdateRequest = request;
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
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success(<WorkflowSummary>[]);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) => Stream.value(const WorkflowDeletionSucceeded());
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

  group('changeNodeType', () {
    test(
      'confirm with drops switches type, drops unsupported fields, and saves',
      () async {
        final repo = _FakeWorkflowRepository();
        const node = WorkflowNode(
          id: 'n1',
          type: NodeTypeId.claudeCode,
          label: 'Coder',
          position: WorkflowPosition(x: 10, y: 20),
          config: <String, dynamic>{
            'effort': 'high',
            'model': 'm',
            'agentId': 'a1',
          },
        );
        const edge = WorkflowEdge(
          id: 'e1',
          sourceNodeId: 'n1',
          sourceOutput: NodeOutput.onSuccess,
          targetNodeId: 'n2',
        );
        repo.stored = repo.stored.copyWith(
          nodes: <WorkflowNode>[node],
          edges: <WorkflowEdge>[edge],
          entryNodeId: 'n1',
        );
        final container = ProviderContainer.test(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        );

        final provider = workflowEditorControllerProvider('wf-1');
        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        final result = await notifier.changeNodeType(
          'n1',
          NodeTypeId.geminiCli,
        );
        expect(result, isA<Success<WorkflowResponse>>());

        final savedNodes = repo.lastUpdateRequest!.nodes;
        expect(savedNodes, hasLength(1));
        final saved = savedNodes.single;
        expect(saved.id, 'n1');
        expect(saved.type, NodeTypeId.geminiCli);
        expect(saved.label, 'Coder');
        expect(saved.position, const WorkflowPosition(x: 10, y: 20));
        expect(saved.config.containsKey('effort'), isFalse);
        expect(saved.config['model'], 'm');
        expect(saved.config['agentId'], 'a1');
        expect(repo.lastUpdateRequest!.edges, <WorkflowEdge>[edge]);
        expect(repo.lastUpdateRequest!.entryNodeId, 'n1');

        final state = container.read(provider).requireValue;
        expect(state.isDirty, isFalse);
        expect(state.isSaving, isFalse);
      },
    );

    test('no drops keeps whole config and saves', () async {
      final repo = _FakeWorkflowRepository();
      const node = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.claudeCode,
        label: 'Coder',
        position: WorkflowPosition(x: 0, y: 0),
        config: <String, dynamic>{'effort': 'high', 'model': 'm'},
      );
      repo.stored = repo.stored.copyWith(nodes: <WorkflowNode>[node]);
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final provider = workflowEditorControllerProvider('wf-1');
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final result = await notifier.changeNodeType('n1', NodeTypeId.codex);
      expect(result, isA<Success<WorkflowResponse>>());
      final saved = repo.lastUpdateRequest!.nodes.single;
      expect(saved.type, NodeTypeId.codex);
      expect(saved.config, <String, dynamic>{'effort': 'high', 'model': 'm'});
    });

    test('refused on terminal node or same type without saving', () async {
      final repo = _FakeWorkflowRepository();
      const terminal = WorkflowNode(
        id: 't1',
        type: NodeTypeId.terminal,
        label: 'Done',
        position: WorkflowPosition(x: 0, y: 0),
      );
      const claude = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.claudeCode,
        label: 'Coder',
        position: WorkflowPosition(x: 10, y: 0),
      );
      repo.stored = repo.stored.copyWith(
        nodes: <WorkflowNode>[terminal, claude],
      );
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final provider = workflowEditorControllerProvider('wf-1');
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final r1 = await notifier.changeNodeType('t1', NodeTypeId.geminiCli);
      expect(r1, isA<FailureResult<WorkflowResponse>>());
      expect(repo.lastUpdateRequest, isNull);

      final r2 = await notifier.changeNodeType('n1', NodeTypeId.claudeCode);
      expect(r2, isA<FailureResult<WorkflowResponse>>());
      expect(repo.lastUpdateRequest, isNull);
    });

    test('save error sets saveFailure and keeps new type in draft', () async {
      final repo = _FakeWorkflowRepository();
      const node = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.claudeCode,
        label: 'Coder',
        position: WorkflowPosition(x: 0, y: 0),
      );
      repo.stored = repo.stored.copyWith(nodes: <WorkflowNode>[node]);
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final provider = workflowEditorControllerProvider('wf-1');
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      repo.saveOverride = const FailureResult(NetworkFailure('offline'));

      final result = await notifier.changeNodeType('n1', NodeTypeId.geminiCli);
      expect(result, isA<FailureResult<WorkflowResponse>>());

      final state = container.read(provider).requireValue;
      expect(state.saveFailure, isA<NetworkFailure>());
      expect(state.isSaving, isFalse);
      expect(state.workflow.nodes.single.type, NodeTypeId.geminiCli);
    });

    test(
      'updateNodeConfig with fallback list saves through revision-checked path',
      () async {
        final repo = _FakeWorkflowRepository();
        const node = WorkflowNode(
          id: 'n1',
          type: NodeTypeId.claudeCode,
          label: 'Coder',
          position: WorkflowPosition(x: 0, y: 0),
        );
        repo.stored = repo.stored.copyWith(nodes: <WorkflowNode>[node]);
        final container = ProviderContainer.test(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        );

        final provider = workflowEditorControllerProvider('wf-1');
        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        final updatedConfig = const HarnessNodeConfig(
          fallback: <FallbackEntry>[
            FallbackEntry(harness: NodeTypeId.codex, model: 'gpt-x'),
          ],
        ).toJson();
        notifier.updateNodeConfig('n1', updatedConfig);

        final result = await notifier.save();
        expect(result, isA<Success<WorkflowResponse>>());
        expect(repo.lastUpdateRequest?.revision, 'rev-1');
        expect(
          repo.lastUpdateRequest?.nodes.single.config['fallback'],
          <JsonMap>[
            <String, dynamic>{'harness': NodeTypeId.codex, 'model': 'gpt-x'},
          ],
        );
      },
    );
  });
}
