import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_changes_source.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 20, 12);
  int getCalls = 0;
  String revision = 'rev-1';

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
    getCalls++;
    return Success(
      WorkflowResponse(
        workflow: stored,
        validation: const WorkflowValidationResult(isValid: true),
        revision: revision,
      ),
    );
  }

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));

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

final class _FakeChangesSource implements WorkflowChangesSource {
  const new(this.changes);

  @override
  final Stream<WorkflowsChangedPayload> changes;
}

final DateTime _at = DateTime.utc(2026, 11, 20, 12);

WorkflowNode _node(String id) => WorkflowNode(
  id: id,
  type: NodeTypeId.command,
  label: 'Step $id',
  position: const WorkflowPosition(x: 0, y: 0),
);

WorkflowsChangedPayload _change({
  WorkflowChangeKind kind = WorkflowChangeKind.updated,
  String id = 'wf-1',
  String? workspaceId,
  String revision = 'rev-2',
}) => WorkflowsChangedPayload(
  kind: kind,
  id: id,
  workspaceId: workspaceId,
  workflow: WorkflowSummary(
    id: id,
    name: 'Test Flow',
    nodeCount: 0,
    edgeCount: 0,
    hasValidationErrors: false,
    updatedAt: _at,
    revision: revision,
  ),
);

/// Opens the editor for `wf-1` and keeps it alive for the test.
Future<ProviderContainer> _open(
  _FakeWorkflowRepository repo,
  StreamController<WorkflowsChangedPayload> changes, {
  String? workspaceId,
}) async {
  final container = ProviderContainer.test(
    overrides: [
      workflowRepositoryProvider.overrideWithValue(repo),
      workflowChangesSourceProvider.overrideWithValue(
        _FakeChangesSource(changes.stream),
      ),
    ],
  );
  final provider = workflowEditorControllerProvider(
    'wf-1',
    scope: DefinitionScope.ofWorkspaceId(workspaceId),
  );
  container.listen(provider, (_, _) {});
  await container.read(provider.future);
  return container;
}

WorkflowEditorState _state(
  ProviderContainer container, {
  String? workspaceId,
}) => container
    .read(
      workflowEditorControllerProvider(
        'wf-1',
        scope: DefinitionScope.ofWorkspaceId(workspaceId),
      ),
    )
    .requireValue;

void main() {
  late _FakeWorkflowRepository repo;
  late StreamController<WorkflowsChangedPayload> changes;

  setUp(() {
    repo = _FakeWorkflowRepository();
    changes = StreamController<WorkflowsChangedPayload>.broadcast();
  });

  tearDown(() async {
    await changes.close();
  });

  test(
    'an external update of the open workflow reloads a clean editor',
    () async {
      final container = await _open(repo, changes);
      addTearDown(container.dispose);
      repo.stored = repo.stored.copyWith(name: 'Renamed');
      repo.revision = 'rev-2';

      changes.add(_change());
      await pumpEventQueue();

      final state = _state(container);
      expect(state.workflow.name, 'Renamed');
      expect(state.revision, 'rev-2');
      expect(state.isDirty, isFalse);
      expect(repo.getCalls, 2);
    },
  );

  test('the selection is kept when the node still exists', () async {
    repo.stored = repo.stored.copyWith(nodes: [_node('n1'), _node('n2')]);
    final container = await _open(repo, changes);
    addTearDown(container.dispose);
    container
        .read(workflowEditorControllerProvider('wf-1').notifier)
        .selectNode('n1');
    repo.stored = repo.stored.copyWith(
      nodes: [
        _node('n1').copyWith(label: 'Changed'),
        _node('n2'),
      ],
    );
    repo.revision = 'rev-2';

    changes.add(_change());
    await pumpEventQueue();

    final state = _state(container);
    expect(state.selectedNodeId, 'n1');
    expect(state.workflow.nodes.first.label, 'Changed');
  });

  test('the selection is cleared when the node is gone', () async {
    repo.stored = repo.stored.copyWith(nodes: [_node('n1'), _node('n2')]);
    final container = await _open(repo, changes);
    addTearDown(container.dispose);
    container
        .read(workflowEditorControllerProvider('wf-1').notifier)
        .selectNode('n1');
    repo.stored = repo.stored.copyWith(nodes: [_node('n2')]);
    repo.revision = 'rev-2';

    changes.add(_change());
    await pumpEventQueue();

    expect(_state(container).selectedNodeId, isNull);
    expect(_state(container).workflow.nodes.map((n) => n.id), ['n2']);
  });

  test('an update of another workflow is ignored', () async {
    final container = await _open(repo, changes);
    addTearDown(container.dispose);

    changes.add(_change(id: 'wf-2'));
    await pumpEventQueue();

    expect(repo.getCalls, 1);
  });

  test('an update in another scope is ignored', () async {
    final container = await _open(repo, changes);
    addTearDown(container.dispose);

    changes.add(_change(workspaceId: 'ws-1'));
    await pumpEventQueue();

    expect(repo.getCalls, 1);
  });

  test("a workspace editor reloads on its workspace's update", () async {
    final container = await _open(repo, changes, workspaceId: 'ws-1');
    addTearDown(container.dispose);

    changes.add(_change(workspaceId: 'ws-1'));
    await pumpEventQueue();

    expect(repo.getCalls, 2);
  });

  test('an event with the loaded revision does not reload', () async {
    final container = await _open(repo, changes);
    addTearDown(container.dispose);

    changes.add(_change(revision: 'rev-1'));
    await pumpEventQueue();

    expect(repo.getCalls, 1);
  });

  test('a dirty editor keeps its draft', () async {
    final container = await _open(repo, changes);
    addTearDown(container.dispose);
    container
        .read(workflowEditorControllerProvider('wf-1').notifier)
        .addNode(typeId: NodeTypeId.command, defaultLabel: 'Step');
    repo.stored = repo.stored.copyWith(name: 'Renamed');
    repo.revision = 'rev-2';

    changes.add(_change());
    await pumpEventQueue();

    final state = _state(container);
    expect(state.workflow.nodes, hasLength(1));
    expect(state.isDirty, isTrue);
    expect(repo.getCalls, 1);
  });

  test('a created or deleted event is ignored', () async {
    final container = await _open(repo, changes);
    addTearDown(container.dispose);

    changes
      ..add(_change(kind: WorkflowChangeKind.created))
      ..add(_change(kind: WorkflowChangeKind.deleted));
    await pumpEventQueue();

    expect(repo.getCalls, 1);
  });
}
