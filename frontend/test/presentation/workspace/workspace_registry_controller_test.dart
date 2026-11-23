import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_workspace_repository.dart';

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  String? savedId;
  final List<String?> saveCalls = <String?>[];

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async {
    savedId = workspaceId;
    saveCalls.add(workspaceId);
  }
}

void main() {
  late FakeWorkspaceRepository repo;
  late _FakeSelectionStore selectionStore;

  setUp(() {
    repo = FakeWorkspaceRepository();
    selectionStore = _FakeSelectionStore();
  });

  ProviderContainer createContainer() => ProviderContainer.test(
    overrides: [
      workspaceRepositoryProvider.overrideWithValue(repo),
      workspaceSelectionStoreProvider.overrideWithValue(selectionStore),
    ],
  );

  test('restores the last open workspace when it still exists', () async {
    final ws1 = makeWorkspace(name: 'One');
    final ws2 = makeWorkspace(id: 'ws-2', name: 'Two');
    repo.workspaces = [ws1, ws2];
    selectionStore.savedId = 'ws-2';

    final container = createContainer();
    final state = await container.read(
      workspaceRegistryControllerProvider.future,
    );

    expect(state.workspaces, [ws1, ws2]);
    expect(state.currentWorkspaceId, 'ws-2');
    expect(state.currentWorkspace, ws2);
  });

  test(
    'falls back to first workspace when saved workspace is missing',
    () async {
      final ws1 = makeWorkspace(name: 'One');
      repo.workspaces = [ws1];
      selectionStore.savedId = 'ws-deleted';

      final container = createContainer();
      final state = await container.read(
        workspaceRegistryControllerProvider.future,
      );

      expect(state.currentWorkspaceId, 'ws-1');
    },
  );

  test('selectWorkspace updates currentWorkspace and persists id', () async {
    final ws1 = makeWorkspace(name: 'One');
    final ws2 = makeWorkspace(id: 'ws-2', name: 'Two');
    repo.workspaces = [ws1, ws2];

    final container = createContainer();
    await container.read(workspaceRegistryControllerProvider.future);

    await container
        .read(workspaceRegistryControllerProvider.notifier)
        .selectWorkspace('ws-2');

    final state = container.read(workspaceRegistryControllerProvider).value!;
    expect(state.currentWorkspaceId, 'ws-2');
    expect(selectionStore.savedId, 'ws-2');
  });

  test('selectGlobal clears the workspace, survives a refresh and is left '
      'by selecting a workspace', () async {
    final ws1 = makeWorkspace(name: 'One');
    repo.workspaces = [ws1];
    final container = createContainer();
    await container.read(workspaceRegistryControllerProvider.future);
    final notifier = container.read(
      workspaceRegistryControllerProvider.notifier,
    )..selectGlobal();
    var state = container.read(workspaceRegistryControllerProvider).value!;
    expect(state.isGlobalSelected, isTrue);
    expect(state.currentWorkspaceId, isNull);

    await notifier.refresh();
    state = container.read(workspaceRegistryControllerProvider).value!;
    expect(state.isGlobalSelected, isTrue);
    expect(state.currentWorkspaceId, isNull);

    await notifier.selectWorkspace('ws-1');
    state = container.read(workspaceRegistryControllerProvider).value!;
    expect(state.isGlobalSelected, isFalse);
    expect(state.currentWorkspaceId, 'ws-1');
  });

  test('addWorkspace registers, selects, and persists new workspace', () async {
    final container = createContainer();
    await container.read(workspaceRegistryControllerProvider.future);

    final result = await container
        .read(workspaceRegistryControllerProvider.notifier)
        .addWorkspace(rootPath: '/tmp/my-app', name: 'My App');

    expect(result.isSuccess, isTrue);
    final state = container.read(workspaceRegistryControllerProvider).value!;
    expect(state.workspaces.single.name, 'My App');
    expect(state.currentWorkspaceId, state.workspaces.single.id);
    expect(selectionStore.savedId, state.workspaces.single.id);
  });

  test('renameWorkspace updates the workspace name in state', () async {
    final ws1 = makeWorkspace(name: 'Old');
    repo.workspaces = [ws1];

    final container = createContainer();
    await container.read(workspaceRegistryControllerProvider.future);

    final result = await container
        .read(workspaceRegistryControllerProvider.notifier)
        .renameWorkspace('ws-1', name: 'New Name');

    expect(result.isSuccess, isTrue);
    final state = container.read(workspaceRegistryControllerProvider).value!;
    expect(state.workspaces.single.name, 'New Name');
    expect(state.currentWorkspace?.name, 'New Name');
  });

  test(
    'removeWorkspace unregisters and switches to next workspace or null',
    () async {
      final ws1 = makeWorkspace(name: 'One');
      final ws2 = makeWorkspace(id: 'ws-2', name: 'Two');
      repo.workspaces = [ws1, ws2];
      selectionStore.savedId = 'ws-1';

      final container = createContainer();
      await container.read(workspaceRegistryControllerProvider.future);

      final result = await container
          .read(workspaceRegistryControllerProvider.notifier)
          .removeWorkspace('ws-1');

      expect(result.isSuccess, isTrue);
      var state = container.read(workspaceRegistryControllerProvider).value!;
      expect(state.workspaces, [ws2]);
      expect(state.currentWorkspaceId, 'ws-2');
      expect(selectionStore.savedId, 'ws-2');

      await container
          .read(workspaceRegistryControllerProvider.notifier)
          .removeWorkspace('ws-2');

      state = container.read(workspaceRegistryControllerProvider).value!;
      expect(state.workspaces, isEmpty);
      expect(state.currentWorkspaceId, isNull);
      expect(selectionStore.savedId, isNull);
    },
  );
}
