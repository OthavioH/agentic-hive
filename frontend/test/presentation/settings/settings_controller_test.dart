import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/settings/file_picker_data_source.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_frontend/presentation/settings/controllers/settings_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeSettingsRepository implements SettingsRepository {
  Result<AppSettings> getResult = const Success(
    AppSettings(
      effectiveAgentsDir: '/default/agents',
      defaultAgentsDir: '/default/agents',
    ),
  );
  Result<AppSettings> updateResult = const Success(
    AppSettings(
      effectiveAgentsDir: '/default/agents',
      defaultAgentsDir: '/default/agents',
    ),
  );
  Completer<Result<AppSettings>>? pendingUpdate;
  UpdateSettingsRequest? lastRequest;
  final StreamController<AppSettings> updates =
      StreamController<AppSettings>.broadcast();

  @override
  Future<Result<AppSettings>> getSettings() async => getResult;

  @override
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request) {
    lastRequest = request;
    if (pendingUpdate != null) {
      return pendingUpdate!.future;
    }
    return Future<Result<AppSettings>>.value(updateResult);
  }

  @override
  Stream<AppSettings> watchSettingsUpdates() => updates.stream;

  Future<void> dispose() => updates.close();
}

final class _FakeFilePickerDataSource implements FilePickerDataSource {
  String? nextDirectory;
  String? nextFile;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async =>
      nextDirectory;

  @override
  Future<String?> pickFile({String? initialDirectory}) async => nextFile;
}

void main() {
  const initialSettings = AppSettings(
    agentsDir: '/custom/agents',
    effectiveAgentsDir: '/custom/agents',
    defaultAgentsDir: '/default/agents',
    defaultWorkspaceDir: '/workspace',
    harnessOverrides: <HarnessId, String>{
      HarnessId.claudeCode: '/usr/local/bin/claude',
    },
  );

  group('SettingsController', () {
    test('loads initial settings and tracks dirty state', () async {
      final repo = _FakeSettingsRepository()
        ..getResult = const Success(initialSettings);
      addTearDown(repo.dispose);
      final picker = _FakeFilePickerDataSource();

      final container = ProviderContainer.test(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          filePickerDataSourceProvider.overrideWithValue(picker),
        ],
      );

      final initial = await container.read(settingsControllerProvider.future);
      expect(initial.hasUnsavedChanges, isFalse);
      expect(initial.agentsDirDraft, '/custom/agents');
      expect(initial.defaultWorkspaceDirDraft, '/workspace');
      expect(
        initial.harnessOverridesDraft[HarnessId.claudeCode],
        '/usr/local/bin/claude',
      );

      final notifier = container.read(settingsControllerProvider.notifier)
        ..setAgentsDir('/other/agents');
      final dirty = container.read(settingsControllerProvider).requireValue;
      expect(dirty.hasUnsavedChanges, isTrue);

      notifier.discard();
      final reverted = container.read(settingsControllerProvider).requireValue;
      expect(reverted.hasUnsavedChanges, isFalse);
      expect(reverted.agentsDirDraft, '/custom/agents');
    });

    test(
      'save updates snapshot and preserves draft with fieldErrors on failure',
      () async {
        final repo = _FakeSettingsRepository()
          ..getResult = const Success(initialSettings);
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        );
        final sub = container.listen(settingsControllerProvider, (_, _) {});
        addTearDown(sub.close);

        await container.read(settingsControllerProvider.future);
        final notifier = container.read(settingsControllerProvider.notifier)
          ..setAgentsDir('/invalid/agents')
          ..setHarnessOverride(HarnessId.codex, '/invalid/codex');

        repo.updateResult = const FailureResult<AppSettings>(
          ValidationFailure(
            'Validation failed',
            details: <String, String>{
              'agentsDir': 'Agents folder does not exist.',
              'harnessOverrides.codex': 'Not executable.',
            },
          ),
        );

        final failResult = await notifier.save();
        expect(failResult, isA<FailureResult<void>>());
        final failedState = container
            .read(settingsControllerProvider)
            .requireValue;
        expect(failedState.isSaving, isFalse);
        expect(failedState.agentsDirDraft, '/invalid/agents');
        expect(
          failedState.fieldErrors['agentsDir'],
          'Agents folder does not exist.',
        );
        expect(
          failedState.fieldErrors['harnessOverrides.codex'],
          'Not executable.',
        );

        // Editing a field clears its inline error.
        notifier.setAgentsDir('/valid/agents');
        expect(
          container
              .read(settingsControllerProvider)
              .requireValue
              .fieldErrors
              .containsKey('agentsDir'),
          isFalse,
        );

        const savedSettings = AppSettings(
          agentsDir: '/valid/agents',
          effectiveAgentsDir: '/valid/agents',
          defaultAgentsDir: '/default/agents',
          defaultWorkspaceDir: '/workspace',
          harnessOverrides: <HarnessId, String>{
            HarnessId.claudeCode: '/usr/local/bin/claude',
            HarnessId.codex: '/invalid/codex',
          },
        );
        repo.updateResult = const Success(savedSettings);

        final okResult = await notifier.save();
        expect(okResult, isA<Success<void>>());
        final savedState = container
            .read(settingsControllerProvider)
            .requireValue;
        expect(savedState.hasUnsavedChanges, isFalse);
        expect(savedState.fieldErrors, isEmpty);
        expect(savedState.saved, savedSettings);
      },
    );

    test('reset, clear, and browse actions update drafts cleanly', () async {
      final repo = _FakeSettingsRepository()
        ..getResult = const Success(initialSettings);
      addTearDown(repo.dispose);
      final picker = _FakeFilePickerDataSource()
        ..nextDirectory = '/picked/dir'
        ..nextFile = '/picked/gemini';

      final container = ProviderContainer.test(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          filePickerDataSourceProvider.overrideWithValue(picker),
        ],
      );

      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier)
        ..resetAgentsDirToDefault()
        ..clearDefaultWorkspaceDir()
        ..clearHarnessOverride(HarnessId.claudeCode);

      var state = container.read(settingsControllerProvider).requireValue;
      expect(state.agentsDirDraft, '/default/agents');
      expect(state.defaultWorkspaceDirDraft, '');
      expect(state.harnessOverridesDraft, isEmpty);
      expect(state.toUpdateRequest().agentsDir, isNull);
      expect(state.toUpdateRequest().defaultWorkspaceDir, isNull);

      await notifier.browseAgentsDir();
      await notifier.browseDefaultWorkspaceDir();
      await notifier.browseHarnessExecutable(HarnessId.geminiCli);

      state = container.read(settingsControllerProvider).requireValue;
      expect(state.agentsDirDraft, '/picked/dir');
      expect(state.defaultWorkspaceDirDraft, '/picked/dir');
      expect(
        state.harnessOverridesDraft[HarnessId.geminiCli],
        '/picked/gemini',
      );
    });

    test(
      'live settingsUpdated stream updates clean state and keeps dirty draft',
      () async {
        final repo = _FakeSettingsRepository()
          ..getResult = const Success(initialSettings);
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        );
        final sub = container.listen(settingsControllerProvider, (_, _) {});
        addTearDown(sub.close);

        await container.read(settingsControllerProvider.future);

        const remoteUpdate = AppSettings(
          agentsDir: '/remote/agents',
          effectiveAgentsDir: '/remote/agents',
          defaultAgentsDir: '/default/agents',
        );
        repo.updates.add(remoteUpdate);
        await Future<void>.delayed(Duration.zero);

        var state = container.read(settingsControllerProvider).requireValue;
        expect(state.agentsDirDraft, '/remote/agents');
        expect(state.hasUnsavedChanges, isFalse);

        // Now make local draft dirty, then emit another remote update.
        container
            .read(settingsControllerProvider.notifier)
            .setAgentsDir('/local/draft');
        const remoteUpdate2 = AppSettings(
          agentsDir: '/remote/agents2',
          effectiveAgentsDir: '/remote/agents2',
          defaultAgentsDir: '/default/agents',
        );
        repo.updates.add(remoteUpdate2);
        await Future<void>.delayed(Duration.zero);

        state = container.read(settingsControllerProvider).requireValue;
        expect(state.saved, remoteUpdate2);
        expect(state.agentsDirDraft, '/local/draft');
      },
    );

    test(
      'preserves edits typed while save is in flight without overwriting',
      () async {
        final pending = Completer<Result<AppSettings>>();
        final repo = _FakeSettingsRepository()
          ..getResult = const Success(initialSettings)
          ..pendingUpdate = pending;
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        );
        final sub = container.listen(settingsControllerProvider, (_, _) {});
        addTearDown(sub.close);

        await container.read(settingsControllerProvider.future);
        final notifier = container.read(settingsControllerProvider.notifier)
          ..setAgentsDir('/saved/agents');

        final saveFuture = notifier.save();
        // Simulate edit to defaultWorkspaceDir while save() is in flight.
        notifier.setDefaultWorkspaceDir('/new/workspace');

        pending.complete(
          const Success(
            AppSettings(
              agentsDir: '/saved/agents',
              effectiveAgentsDir: '/saved/agents',
              defaultAgentsDir: '/default/agents',
              defaultWorkspaceDir: '/workspace',
              harnessOverrides: <HarnessId, String>{
                HarnessId.claudeCode: '/usr/local/bin/claude',
              },
            ),
          ),
        );
        await saveFuture;

        final after = container.read(settingsControllerProvider).requireValue;
        expect(after.agentsDirDraft, '/saved/agents');
        expect(after.defaultWorkspaceDirDraft, '/new/workspace');
        expect(after.hasUnsavedChanges, isTrue);
      },
    );
  });
}
