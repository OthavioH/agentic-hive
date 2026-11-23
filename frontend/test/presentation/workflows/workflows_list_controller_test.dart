import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_changes_source.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflows_list_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../workspace/fake_workspace_repository.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 20, 12);
  Result<List<WorkflowSummary>>? listOverride;
  final List<String?> listedScopes = <String?>[];
  final List<String?> deletedScopes = <String?>[];
  final List<String?> createdScopes = <String?>[];
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
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    String? workspaceId,
  }) async {
    listedScopes.add(workspaceId);
    if (listOverride != null) return listOverride!;
    return Success(List<WorkflowSummary>.from(items));
  }

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async {
    createdScopes.add(request.workspaceId);
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
    String? workspaceId,
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
  Future<Result<void>> deleteWorkflow(String id, {String? workspaceId}) async {
    deletedScopes.add(workspaceId);
    if (deleteOverride.isFailure) return deleteOverride;
    items.removeWhere((w) => w.id == id);
    return const Success<void>(null);
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

final class _FakeChangesSource implements WorkflowChangesSource {
  const new(this.changes);

  @override
  final Stream<WorkflowsChangedPayload> changes;
}

final class _MemorySelectionStore implements WorkspaceSelectionStore {
  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String? workspaceId) async {}
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

    group('workspace scope', () {
      late FakeWorkspaceRepository workspaces;
      final changes = StreamController<WorkflowsChangedPayload>.broadcast();

      setUp(() => workspaces = FakeWorkspaceRepository());
      tearDown(() async {
        // Subscriptions are cancelled by the container; keep the controller.
      });

      ProviderContainer scopedContainer(_FakeWorkflowRepository repo) =>
          ProviderContainer.test(
            overrides: [
              workflowRepositoryProvider.overrideWithValue(repo),
              workflowChangesSourceProvider.overrideWithValue(
                _FakeChangesSource(changes.stream),
              ),
              workspaceRepositoryProvider.overrideWithValue(workspaces),
              workspaceSelectionStoreProvider.overrideWithValue(
                _MemorySelectionStore(),
              ),
            ],
          );

      test('lists the current workspace plus global workflows', () async {
        workspaces.workspaces = [makeWorkspace(name: 'One')];
        final repo = _FakeWorkflowRepository()..seedDefaults();
        final container = scopedContainer(repo);
        await container.read(workspaceRegistryControllerProvider.future);

        await container.read(workflowsListControllerProvider.future);

        expect(repo.listedScopes.last, 'ws-1');
      });

      test('the Global entry lists only global workflows', () async {
        workspaces.workspaces = [makeWorkspace(name: 'One')];
        final repo = _FakeWorkflowRepository()..seedDefaults();
        final container = scopedContainer(repo);
        await container.read(workspaceRegistryControllerProvider.future);
        await container.read(workflowsListControllerProvider.future);

        container
            .read(workspaceRegistryControllerProvider.notifier)
            .selectGlobal();
        await container.read(workflowsListControllerProvider.future);

        expect(repo.listedScopes.last, isNull);
      });

      test('creates and deletes in the requested scope', () async {
        workspaces.workspaces = [makeWorkspace(name: 'One')];
        final repo = _FakeWorkflowRepository()..seedDefaults();
        final container = scopedContainer(repo);
        await container.read(workspaceRegistryControllerProvider.future);
        await container.read(workflowsListControllerProvider.future);
        final notifier = container.read(
          workflowsListControllerProvider.notifier,
        );

        await notifier.createWorkflow(name: 'In repo', workspaceId: 'ws-1');
        await notifier.createWorkflow(name: 'Everywhere');
        await notifier.deleteWorkflow('wf-1', workspaceId: 'ws-1');

        expect(repo.createdScopes, ['ws-1', null]);
        expect(repo.deletedScopes, ['ws-1']);
      });

      test('a live change of the current workspace reloads the list', () async {
        workspaces.workspaces = [makeWorkspace(name: 'One')];
        final repo = _FakeWorkflowRepository()..seedDefaults();
        final container = scopedContainer(repo);
        await container.read(workspaceRegistryControllerProvider.future);
        await container.read(workflowsListControllerProvider.future);
        final before = repo.listedScopes.length;

        changes.add(
          const WorkflowsChangedPayload(
            kind: WorkflowChangeKind.created,
            id: 'pulled',
            workspaceId: 'ws-1',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(repo.listedScopes.length, before + 1);

        changes.add(
          const WorkflowsChangedPayload(
            kind: WorkflowChangeKind.created,
            id: 'other',
            workspaceId: 'ws-other',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(repo.listedScopes.length, before + 1);
      });
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
