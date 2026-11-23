import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../workspace/fake_workspace_repository.dart';

final class _SelectionStore implements WorkspaceSelectionStore {
  String? savedId;

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async => savedId = workspaceId;
}

AgentDetail _detail(String id, AgentScope scope, {String name = ''}) =>
    AgentDetail(
      id: id,
      name: name.isEmpty ? id : name,
      contentHash: 'hash-$id-${scope.name}',
      updatedAt: DateTime.utc(2026, 11, 22),
      scope: scope,
    );

/// Repository keyed by `(scope, id)` that records every `workspaceId` it was
/// called with.
final class _ScopedRepository implements AgentRepository {
  final global = <String, AgentDetail>{};
  final workspace = <String, AgentDetail>{};
  final changes = StreamController<AgentsChangedPayload>.broadcast();
  final listCalls = <String?>[];
  final getCalls = <({String id, String? workspaceId})>[];
  final createCalls = <String?>[];
  final updateCalls = <({String id, String? workspaceId})>[];
  final deleteCalls = <({String id, String? workspaceId})>[];

  @override
  Future<Result<List<AgentSummary>>> listAgents({String? workspaceId}) async {
    listCalls.add(workspaceId);
    final workspaceItems = workspaceId == null
        ? const <AgentDetail>[]
        : workspace.values.toList();
    final ids = {for (final d in workspaceItems) d.id};
    return Success([
      for (final d in workspaceItems) _summary(d),
      for (final d in global.values)
        _summary(d).copyWith(overridden: ids.contains(d.id)),
    ]);
  }

  AgentSummary _summary(AgentDetail d) => AgentSummary(
    id: d.id,
    name: d.name,
    contentHash: d.contentHash,
    updatedAt: d.updatedAt,
    scope: d.scope,
  );

  @override
  Future<Result<AgentDetail>> getAgent(String id, {String? workspaceId}) async {
    getCalls.add((id: id, workspaceId: workspaceId));
    final found = (workspaceId == null ? null : workspace[id]) ?? global[id];
    return found == null
        ? const FailureResult(NotFoundFailure('missing'))
        : Success(found);
  }

  @override
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    String? workspaceId,
  }) async {
    createCalls.add(workspaceId);
    final scope = workspaceId == null
        ? AgentScope.global
        : AgentScope.workspace;
    final created = _detail(request.id, scope, name: request.name);
    (workspaceId == null ? global : workspace)[request.id] = created;
    return Success(created);
  }

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    String? workspaceId,
  }) async {
    updateCalls.add((id: id, workspaceId: workspaceId));
    final store = workspaceId == null ? global : workspace;
    final updated = store[id]!.copyWith(name: request.name);
    store[id] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteAgent(String id, {String? workspaceId}) async {
    deleteCalls.add((id: id, workspaceId: workspaceId));
    (workspaceId == null ? global : workspace).remove(id);
    return const Success(null);
  }

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() => changes.stream;
}

void main() {
  late _ScopedRepository agents;
  late FakeWorkspaceRepository workspaces;
  late _SelectionStore store;

  Workspace workspace(String id) => Workspace(
    id: id,
    name: 'Repo $id',
    rootPath: '/repos/$id',
    isGit: true,
    createdAt: DateTime.utc(2026, 11, 22),
    updatedAt: DateTime.utc(2026, 11, 22),
  );

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer.test(
      overrides: [
        agentRepositoryProvider.overrideWithValue(agents),
        workspaceRepositoryProvider.overrideWithValue(workspaces),
        workspaceSelectionStoreProvider.overrideWithValue(store),
      ],
    )..listen(agentsControllerProvider, (_, _) {});
    await container.read(workspaceRegistryControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  setUp(() {
    agents = _ScopedRepository();
    addTearDown(agents.changes.close);
    workspaces = FakeWorkspaceRepository(workspaces: [workspace('ws-1')]);
    store = _SelectionStore()..savedId = 'ws-1';
  });

  test('lists the current workspace plus global agents with scopes', () async {
    agents.global['planner'] = _detail('planner', AgentScope.global);
    agents.global['reviewer'] = _detail('reviewer', AgentScope.global);
    agents.workspace['reviewer'] = _detail('reviewer', AgentScope.workspace);

    final container = await boot();

    expect(agents.listCalls.last, 'ws-1');
    final list = container.read(agentsControllerProvider).agents.value!;
    expect(
      [for (final a in list) '${a.id}:${a.scope.name}:${a.overridden}'],
      unorderedEquals([
        'planner:global:false',
        'reviewer:workspace:false',
        'reviewer:global:true',
      ]),
    );
  });

  test('Global view lists and edits only global agents', () async {
    agents.global['planner'] = _detail('planner', AgentScope.global);
    agents.workspace['only-ws'] = _detail('only-ws', AgentScope.workspace);
    final container = await boot();
    final controller = container.read(agentsControllerProvider.notifier);

    await controller.setGlobalOnly(true);

    expect(container.read(agentsControllerProvider).globalOnly, isTrue);
    expect(agents.listCalls.last, isNull);
    expect(
      container.read(agentsControllerProvider).agents.value!.map((a) => a.id),
      ['planner'],
    );

    controller
      ..startCreate()
      ..updateName('New Global');
    await controller.save();
    expect(agents.createCalls.last, isNull);
  });

  test('creating in the workspace view writes to the workspace', () async {
    final container = await boot();
    final controller = container.read(agentsControllerProvider.notifier)
      ..startCreate()
      ..updateName('Planner');

    await controller.save();

    expect(agents.createCalls.single, 'ws-1');
    expect(
      container.read(agentsControllerProvider).detail.value?.scope,
      AgentScope.workspace,
    );
  });

  test('editing a global agent from a workspace view targets global', () async {
    agents.global['planner'] = _detail('planner', AgentScope.global);
    final container = await boot();
    final controller = container.read(agentsControllerProvider.notifier);

    await controller.selectAgent('planner', scope: AgentScope.global);
    expect(agents.getCalls.last.workspaceId, isNull);
    controller.updateName('Planner v2');
    await controller.save();

    expect(agents.updateCalls.single.workspaceId, isNull);
  });

  test('selecting an overridden global entry loads the global file', () async {
    agents.global['reviewer'] = _detail('reviewer', AgentScope.global);
    agents.workspace['reviewer'] = _detail('reviewer', AgentScope.workspace);
    final container = await boot();
    final controller = container.read(agentsControllerProvider.notifier);

    await controller.selectAgent('reviewer', scope: AgentScope.workspace);
    expect(
      container.read(agentsControllerProvider).detail.value?.scope,
      AgentScope.workspace,
    );
    await controller.selectAgent('reviewer', scope: AgentScope.global);
    expect(
      container.read(agentsControllerProvider).detail.value?.scope,
      AgentScope.global,
    );

    await controller.deleteSelected();
    expect(agents.deleteCalls.single.workspaceId, isNull);
    expect(agents.workspace.containsKey('reviewer'), isTrue);
  });

  test('live: an external workspace edit appears without reload', () async {
    final container = await boot();
    final before = agents.listCalls.length;

    agents.changes.add(
      AgentsChangedPayload(
        kind: AgentChangeKind.created,
        id: 'pulled',
        workspaceId: 'ws-1',
        agent: AgentSummary(
          id: 'pulled',
          name: 'Pulled',
          contentHash: 'h',
          updatedAt: DateTime.utc(2026, 11, 22),
          scope: AgentScope.workspace,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final list = container.read(agentsControllerProvider).agents.value!;
    expect(list.map((a) => a.id), ['pulled']);
    expect(list.single.scope, AgentScope.workspace);
    expect(agents.listCalls.length, before);
  });

  test('events of another workspace are ignored', () async {
    final container = await boot();

    agents.changes.add(
      AgentsChangedPayload(
        kind: AgentChangeKind.created,
        id: 'elsewhere',
        workspaceId: 'ws-other',
        agent: AgentSummary(
          id: 'elsewhere',
          name: 'Elsewhere',
          contentHash: 'h',
          updatedAt: DateTime.utc(2026, 11, 22),
          scope: AgentScope.workspace,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(agentsControllerProvider).agents.value, isEmpty);
  });

  test('workspace events are ignored in the Global view', () async {
    final container = await boot();
    await container.read(agentsControllerProvider.notifier).setGlobalOnly(true);

    agents.changes.add(
      AgentsChangedPayload(
        kind: AgentChangeKind.created,
        id: 'pulled',
        workspaceId: 'ws-1',
        agent: AgentSummary(
          id: 'pulled',
          name: 'Pulled',
          contentHash: 'h',
          updatedAt: DateTime.utc(2026, 11, 22),
          scope: AgentScope.workspace,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(agentsControllerProvider).agents.value, isEmpty);
  });

  test('switching workspace reloads the list for the new workspace', () async {
    workspaces.workspaces = [workspace('ws-1'), workspace('ws-2')];
    final container = await boot();

    await container
        .read(workspaceRegistryControllerProvider.notifier)
        .selectWorkspace('ws-2');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(agents.listCalls.last, 'ws-2');
  });
}
