import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/presentation/settings/controllers/settings_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'settings_state.dart';

part 'settings_controller.g.dart';

/// Manages the Settings page form state, draft edits, file/folder picking,
/// validation errors, and Save/Discard actions.
@riverpod
class SettingsController extends _$SettingsController {
  @override
  Future<SettingsState> build() async {
    final watchUpdates = ref.watch(watchSettingsUpdatesProvider);
    final subscription = watchUpdates().listen(_onSettingsUpdated);
    ref.onDispose(() => unawaited(subscription.cancel()));

    final getSettings = ref.watch(getSettingsProvider);
    final result = await getSettings();
    return switch (result) {
      Success<AppSettings>(:final value) => SettingsState.fromAppSettings(
        value,
      ),
      FailureResult<AppSettings>(:final failure) => Error.throwWithStackTrace(
        failure,
        StackTrace.current,
      ),
    };
  }

  /// Updates the draft Agents folder path and clears its inline error.
  void setAgentsDir(String value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        agentsDirDraft: value,
        fieldErrors: _withoutError(current.fieldErrors, 'agentsDir'),
      ),
    );
  }

  /// Resets the draft Agents folder path to [AppSettings.defaultAgentsDir].
  void resetAgentsDirToDefault() {
    final current = state.value;
    if (current == null) return;
    setAgentsDir(current.saved.defaultAgentsDir);
  }

  /// Updates the draft custom executable path for [id] and clears its error.
  void setHarnessOverride(HarnessId id, String value) {
    final current = state.value;
    if (current == null) return;
    final nextOverrides = Map<HarnessId, String>.from(
      current.harnessOverridesDraft,
    );
    if (value.isEmpty) {
      nextOverrides.remove(id);
    } else {
      nextOverrides[id] = value;
    }
    state = AsyncData(
      current.copyWith(
        harnessOverridesDraft: nextOverrides,
        fieldErrors: _withoutError(
          current.fieldErrors,
          'harnessOverrides.${id.wireName}',
        ),
      ),
    );
  }

  /// Clears the custom executable path for [id] to revert to auto-detection.
  void clearHarnessOverride(HarnessId id) => setHarnessOverride(id, '');

  /// Updates the draft automatic skill install toggle.
  void setAutoInstallSkills(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(autoInstallSkillsDraft: value));
  }

  /// Opens the native folder picker for the Agents folder.
  Future<void> browseAgentsDir() async {
    final current = state.value;
    if (current == null) return;
    final initial = current.agentsDirDraft.trim();
    final picked = await ref.read(pickDirectoryProvider)(
      initialDirectory: initial.isEmpty ? null : initial,
    );
    if (!ref.mounted || picked == null) return;
    setAgentsDir(picked);
  }

  /// Opens the native file picker for [id]'s custom executable path.
  Future<void> browseHarnessExecutable(HarnessId id) async {
    final current = state.value;
    if (current == null) return;
    final existing = current.harnessOverridesDraft[id]?.trim() ?? '';
    final initialDir = existing.isEmpty ? null : p.dirname(existing);
    final picked = await ref.read(pickFileProvider)(
      initialDirectory: initialDir,
    );
    if (!ref.mounted || picked == null) return;
    setHarnessOverride(id, picked);
  }

  /// Reverts all draft edits back to the last saved snapshot and clears errors.
  void discard() {
    final current = state.value;
    if (current == null || current.isSaving) return;
    state = AsyncData(SettingsState.fromAppSettings(current.saved));
  }

  /// Saves pending draft edits to the backend.
  ///
  /// Validation errors populate [SettingsState.fieldErrors] while preserving
  /// the user's draft edits.
  Future<Result<void>> save() async {
    final current = state.value;
    if (current == null || current.isSaving || !current.hasUnsavedChanges) {
      return const Success<void>(null);
    }

    state = AsyncData(
      current.copyWith(isSaving: true, fieldErrors: const <String, String>{}),
    );

    final result = await ref.read(updateSettingsProvider)(
      current.toUpdateRequest(),
    );
    if (!ref.mounted) {
      return const FailureResult<void>(
        UnexpectedFailure('Settings controller was disposed.'),
      );
    }

    final latest = state.value ?? current;
    return switch (result) {
      Success<AppSettings>(:final value) => () {
        final next = _mergeSavedWithConcurrentEdits(
          saved: value,
          atSaveStart: current,
          latest: latest,
        );
        state = AsyncData(next);
        return const Success<void>(null);
      }(),
      FailureResult<AppSettings>(:final failure) => () {
        final fieldErrors = failure is ValidationFailure
            ? failure.details
            : const <String, String>{};
        state = AsyncData(
          latest.copyWith(isSaving: false, fieldErrors: fieldErrors),
        );
        return FailureResult<void>(failure);
      }(),
    };
  }

  SettingsState _mergeSavedWithConcurrentEdits({
    required AppSettings saved,
    required SettingsState atSaveStart,
    required SettingsState latest,
  }) {
    final base = SettingsState.fromAppSettings(saved);
    final agentsDirDraft = latest.agentsDirDraft == atSaveStart.agentsDirDraft
        ? base.agentsDirDraft
        : latest.agentsDirDraft;
    final mergedOverrides = Map<HarnessId, String>.from(
      base.harnessOverridesDraft,
    );
    for (final id in HarnessId.values) {
      final started = atSaveStart.harnessOverridesDraft[id] ?? '';
      final current = latest.harnessOverridesDraft[id] ?? '';
      if (current != started) {
        if (current.isEmpty) {
          mergedOverrides.remove(id);
        } else {
          mergedOverrides[id] = current;
        }
      }
    }
    return base.copyWith(
      agentsDirDraft: agentsDirDraft,
      harnessOverridesDraft: mergedOverrides,
      autoInstallSkillsDraft:
          latest.autoInstallSkillsDraft == atSaveStart.autoInstallSkillsDraft
          ? base.autoInstallSkillsDraft
          : latest.autoInstallSkillsDraft,
    );
  }

  void _onSettingsUpdated(AppSettings updated) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    if (!current.hasUnsavedChanges) {
      state = AsyncData(SettingsState.fromAppSettings(updated));
    } else {
      state = AsyncData(current.copyWith(saved: updated));
    }
  }

  Map<String, String> _withoutError(Map<String, String> errors, String key) {
    if (!errors.containsKey(key)) return errors;
    return Map<String, String>.of(errors)..remove(key);
  }
}
