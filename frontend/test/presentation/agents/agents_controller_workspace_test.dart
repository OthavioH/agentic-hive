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

AgentDetail _detail(String id, DefinitionScope scope, {String name = ''}) =>
    AgentDetail(
      id: id,
      name: name.isEmpty ? id : name,
      contentHash: 'hash-$id-${scope.wireName}',
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
  Future<Result<List<AgentSummary>>> listAgents({
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final workspaceId = scope.workspaceIdOrNull;
    listCalls.add(workspaceId);
    final workspaceItems = workspaceId == null
        ? const <AgentDetail>[]
        : workspace.values.toList();
    final names = {for (final d in workspaceItems) d.name.trim()};
    return Success([
      for (final d in workspaceItems) _summary(d),
      for (final d in global.values)
        _summary(d).copyWith(overridden: names.contains(d.name.trim())),
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
  Future<Result<AgentDetail>> getAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final workspaceId = scope.workspaceIdOrNull;
    getCalls.add((id: id, workspaceId: workspaceId));
    final found = (workspaceId == null ? null : workspace[id]) ?? global[id];
    return found == null
        ? const FailureResult(NotFoundFailure('missing'))
        : Success(found);
  }

  @override
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final workspaceId = scope.workspaceIdOrNull;
    createCalls.add(workspaceId);
    final created = _detail(request.id, scope, name: request.name);
    (workspaceId == null ? global : workspace)[request.id] = created;
    return Success(created);
  }

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final workspaceId = scope.workspaceIdOrNull;
    updateCalls.add((id: id, workspaceId: workspaceId));
    final store = workspaceId == null ? global : workspace;
    final updated = store[id]!.copyWith(name: request.name);
    store[id] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final workspaceId = scope.workspaceIdOrNull;
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
    agents.global['planner'] = _detail('planner', const GlobalScope());
    agents.global['reviewer'] = _detail('reviewer', const GlobalScope());
    agents.workspace['reviewer'] = _detail(
      'reviewer',
      const WorkspaceScope('ws-1'),
    );

    final container = await boot();

    expect(agents.listCalls.last, 'ws-1');
    final list = container.read(agentsControllerProvider).agents.value!;
    expect(
      [for (final a in list) '${a.id}:${a.scope.wireName}:${a.overridden}'],
      [
        'planner:global:false',
        'reviewer:global:true',
        'reviewer:workspace:false',
      ],
    );
  });

  test('an override matches on the name, not on the file id', () async {
    agents.global['reviewer-global'] = _detail(
      'reviewer-global',
      const GlobalScope(),
      name: 'Reviewer',
    );
    agents.workspace['reviewer-ws'] = _detail(
      'reviewer-ws',
      const WorkspaceScope('ws-1'),
      name: 'Reviewer',
    );
    final container = await boot();
    final controller = container.read(agentsControllerProvider.notifier);

    final list = container.read(agentsControllerProvider).agents.value!;
    expect(
      [for (final a in list) '${a.id}:${a.scope.wireName}:${a.overridden}'],
      unorderedEquals([
        'reviewer-ws:workspace:false',
        'reviewer-global:global:true',
      ]),
    );

    // The global entry stays addressable by its own file id.
    await controller.selectAgent('reviewer-global', scope: const GlobalScope());
    expect(
      container.read(agentsControllerProvider).detail.value?.id,
      'reviewer-global',
    );
  });

  test(
    'live: a workspace agent with the same name flags the global one',
    () async {
      agents.global['reviewer-global'] = _detail(
        'reviewer-global',
        const GlobalScope(),
        name: 'Reviewer',
      );
      final container = await boot();
      AgentSummary globalEntry() => container
          .read(agentsControllerProvider)
          .agents
          .value!
          .singleWhere((a) => a.scope is GlobalScope);
      expect(globalEntry().overridden, isFalse);

      final workspaceSummary = AgentSummary(
        id: 'reviewer-ws',
        name: ' Reviewer ',
        contentHash: 'h',
        updatedAt: DateTime.utc(2026, 11, 22),
        scope: const WorkspaceScope('ws-1'),
      );
      agents.changes.add(
        AgentsChangedPayload(
          kind: AgentChangeKind.created,
          id: 'reviewer-ws',
          workspaceId: 'ws-1',
          agent: workspaceSummary,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(globalEntry().overridden, isTrue);

      agents.changes.add(
        const AgentsChangedPayload(
          kind: AgentChangeKind.deleted,
          id: 'reviewer-ws',
          workspaceId: 'ws-1',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(globalEntry().overridden, isFalse);
    },
  );

  test('Global view lists and edits only global agents', () async {
    agents.global['planner'] = _detail('planner', const GlobalScope());
    agents.workspace['only-ws'] = _detail(
      'only-ws',
      const WorkspaceScope('ws-1'),
    );
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
      const WorkspaceScope('ws-1'),
    );
  });

  test('editing a global agent from a workspace view targets global', () async {
    agents.global['planner'] = _detail('planner', const GlobalScope());
    final container = await boot();
    final controller = container.read(agentsControllerProvider.notifier);

    await controller.selectAgent('planner', scope: const GlobalScope());
    expect(agents.getCalls.last.workspaceId, isNull);
    controller.updateName('Planner v2');
    await controller.save();

    expect(agents.updateCalls.single.workspaceId, isNull);
  });

  test('selecting an overridden global entry loads the global file', () async {
    agents.global['reviewer'] = _detail('reviewer', const GlobalScope());
    agents.workspace['reviewer'] = _detail(
      'reviewer',
      const WorkspaceScope('ws-1'),
    );
    final container = await boot();
    final controller = container.read(agentsControllerProvider.notifier);

    await controller.selectAgent(
      'reviewer',
      scope: const WorkspaceScope('ws-1'),
    );
    expect(
      container.read(agentsControllerProvider).detail.value?.scope,
      const WorkspaceScope('ws-1'),
    );
    await controller.selectAgent('reviewer', scope: const GlobalScope());
    expect(
      container.read(agentsControllerProvider).detail.value?.scope,
      const GlobalScope(),
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
          scope: const WorkspaceScope('ws-1'),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final list = container.read(agentsControllerProvider).agents.value!;
    expect(list.map((a) => a.id), ['pulled']);
    expect(list.single.scope, const WorkspaceScope('ws-1'));
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
          scope: const WorkspaceScope('ws-other'),
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
          scope: const WorkspaceScope('ws-1'),
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

  test('selectGlobal reconciles AgentsController to globalOnly=true', () async {
    agents.global['planner'] = _detail('planner', const GlobalScope());
    agents.workspace['only-ws'] = _detail(
      'only-ws',
      const WorkspaceScope('ws-1'),
    );
    final container = await boot();

    container.read(workspaceRegistryControllerProvider.notifier).selectGlobal();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(agentsControllerProvider);
    expect(state.globalOnly, isTrue);
    expect(agents.listCalls.last, isNull);
    expect(state.agents.value!.map((a) => a.id), ['planner']);
  });

  test(
    'setGlobalOnly(true) reconciles WorkspaceRegistryController to Global',
    () async {
      final container = await boot();
      await container
          .read(agentsControllerProvider.notifier)
          .setGlobalOnly(true);

      final registry = container
          .read(workspaceRegistryControllerProvider)
          .requireValue;
      expect(registry.isGlobalSelected, isTrue);
      expect(registry.currentWorkspaceId, isNull);
    },
  );
}
