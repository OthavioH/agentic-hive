import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflows_list_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 20, 12);
  Result<List<WorkflowSummary>>? listOverride;
  Result<void> deleteOverride = const Success<void>(null);
  final List<WorkflowSummary> items = <WorkflowSummary>[];

  void seedDefaults() {
    items
      ..clear()
      ..addAll(<WorkflowSummary>[
        WorkflowSummary(
          id: 'wf-1',
          name: 'PR Review',
          description: 'Reviews pull requests',
          nodeCount: 3,
          edgeCount: 2,
          hasValidationErrors: false,
          updatedAt: now,
        ),
        WorkflowSummary(
          id: 'wf-2',
          name: 'Deploy Check',
          description: 'Runs smoke tests',
          nodeCount: 1,
          edgeCount: 0,
          hasValidationErrors: true,
          updatedAt: now,
        ),
      ]);
  }

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows() async {
    if (listOverride != null) return listOverride!;
    return Success(List<WorkflowSummary>.from(items));
  }

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async {
    final wf = Workflow(
      id: 'wf-3',
      name: request.name,
      description: request.description,
      nodes: request.nodes,
      edges: request.edges,
      entryNodeId: request.entryNodeId,
      createdAt: now,
      updatedAt: now,
    );
    items.add(
      WorkflowSummary(
        id: wf.id,
        name: wf.name,
        description: wf.description,
        nodeCount: wf.nodes.length,
        edgeCount: wf.edges.length,
        hasValidationErrors: true,
        updatedAt: now,
      ),
    );
    return Success(
      WorkflowResponse(
        workflow: wf,
        validation: const WorkflowValidationResult(isValid: false),
      ),
    );
  }

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
  }) async {
    final source = items.firstWhere((w) => w.id == id);
    final copy = WorkflowSummary(
      id: '$id-copy',
      name: name ?? '${source.name} (Copy)',
      description: source.description,
      nodeCount: source.nodeCount,
      edgeCount: source.edgeCount,
      hasValidationErrors: source.hasValidationErrors,
      updatedAt: now,
    );
    items.add(copy);
    return Success(
      WorkflowResponse(
        workflow: Workflow(
          id: copy.id,
          name: copy.name,
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        validation: const WorkflowValidationResult(isValid: true),
      ),
    );
  }

  @override
  Future<Result<void>> deleteWorkflow(String id) async {
    if (deleteOverride.isFailure) return deleteOverride;
    items.removeWhere((w) => w.id == id);
    return const Success<void>(null);
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

void main() {
  group('WorkflowsListController', () {
    test('loads workflows and filters by search query', () async {
      final repo = _FakeWorkflowRepository()..seedDefaults();
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      final initial = await container.read(
        workflowsListControllerProvider.future,
      );
      expect(initial.workflows, hasLength(2));
      expect(initial.filteredWorkflows, hasLength(2));

      container
          .read(workflowsListControllerProvider.notifier)
          .setSearchQuery('smoke');
      final filtered = container
          .read(workflowsListControllerProvider)
          .requireValue;
      expect(filtered.filteredWorkflows.map((w) => w.id), <String>['wf-2']);
    });

    test('create, duplicate, and delete update list state', () async {
      final repo = _FakeWorkflowRepository()..seedDefaults();
      final container = ProviderContainer.test(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      );

      await container.read(workflowsListControllerProvider.future);
      final notifier = container.read(workflowsListControllerProvider.notifier);

      final created = await notifier.createWorkflow(name: 'Nightly');
      expect(created.isSuccess, isTrue);
      expect(
        container.read(workflowsListControllerProvider).requireValue.workflows,
        hasLength(3),
      );

      final duplicated = await notifier.duplicateWorkflow('wf-1');
      expect(duplicated.isSuccess, isTrue);
      expect(
        container.read(workflowsListControllerProvider).requireValue.workflows,
        hasLength(4),
      );

      final deleted = await notifier.deleteWorkflow('wf-2');
      expect(deleted.isSuccess, isTrue);
      expect(
        container
            .read(workflowsListControllerProvider)
            .requireValue
            .workflows
            .any((w) => w.id == 'wf-2'),
        isFalse,
      );
    });

    test('surfaces load error in AsyncError', () async {
      final repo = _FakeWorkflowRepository()
        ..listOverride = const FailureResult(NetworkFailure('offline'));
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      )..listen(workflowsListControllerProvider, (_, _) {});

      await expectLater(
        container.read(workflowsListControllerProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
