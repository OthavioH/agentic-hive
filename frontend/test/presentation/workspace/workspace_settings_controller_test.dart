import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_providers.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_settings_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_workspace_settings_repository.dart';

void main() {
  late FakeWorkspaceSettingsRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeWorkspaceSettingsRepository();
    container = ProviderContainer.test(
      overrides: [workspaceSettingsRepositoryProvider.overrideWithValue(repo)],
    );
  });

  test('loads overrides, global and effective values', () async {
    repo.overrides = const ExecutionSettings(defaultShell: 'pwsh');

    final state = await container.read(
      workspaceSettingsControllerProvider('ws-1').future,
    );

    expect(repo.getCalls, ['ws-1']);
    expect(state.response.overrides.defaultShell, 'pwsh');
    expect(state.response.global.defaultShell, 'cmd.exe');
    expect(state.response.effective.defaultShell, 'pwsh');
    expect(state.isSaving, isFalse);
  });

  test('a load failure surfaces as an error state', () async {
    repo.getFailure = const NetworkFailure('down');
    final sub = container.listen(
      workspaceSettingsControllerProvider('ws-1'),
      (_, _) {},
    );
    addTearDown(sub.close);

    await expectLater(
      container.read(workspaceSettingsControllerProvider('ws-1').future),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('save sends the overrides and stores the new response', () async {
    await container.read(workspaceSettingsControllerProvider('ws-1').future);

    final result = await container
        .read(workspaceSettingsControllerProvider('ws-1').notifier)
        .save(
          const ExecutionSettings(
            defaultIsolationMode: WorkspaceIsolationMode.direct,
          ),
        );

    expect(result.isSuccess, isTrue);
    expect(repo.updateCalls.single.workspaceId, 'ws-1');
    final state = container
        .read(workspaceSettingsControllerProvider('ws-1'))
        .requireValue;
    expect(
      state.response.effective.defaultIsolationMode,
      WorkspaceIsolationMode.direct,
    );
    expect(state.isSaving, isFalse);
  });

  test(
    'a failed save keeps the loaded settings and returns the failure',
    () async {
      await container.read(workspaceSettingsControllerProvider('ws-1').future);
      repo.updateFailure = const ValidationFailure('Shell must not be blank.');

      final result = await container
          .read(workspaceSettingsControllerProvider('ws-1').notifier)
          .save(const ExecutionSettings(defaultShell: ' '));

      expect(result.failureOrNull, isA<ValidationFailure>());
      final state = container
          .read(workspaceSettingsControllerProvider('ws-1'))
          .requireValue;
      expect(state.response.overrides.isEmpty, isTrue);
      expect(state.isSaving, isFalse);
    },
  );
}
