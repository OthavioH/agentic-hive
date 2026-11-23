import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

/// Presentation state for the Settings page.
@freezed
sealed class SettingsState with _$SettingsState {
  /// Creates a [SettingsState].
  const factory({
    required AppSettings saved,
    required String agentsDirDraft,
    required Map<HarnessId, String> harnessOverridesDraft,
    @Default(false) bool isSaving,
    @Default(<String, String>{}) Map<String, String> fieldErrors,
  }) = _SettingsState;

  const new _();

  /// Builds an initial [SettingsState] synchronized to [settings].
  factory fromAppSettings(AppSettings settings) => SettingsState(
    saved: settings,
    agentsDirDraft: settings.effectiveAgentsDir,
    harnessOverridesDraft: Map<HarnessId, String>.from(
      settings.harnessOverrides,
    ),
  );

  /// Whether any path or harness override draft differs from [saved].
  bool get hasUnsavedChanges {
    if (agentsDirDraft.trim() != saved.effectiveAgentsDir) return true;
    return !_mapsEqual(normalizedHarnessOverrides, saved.harnessOverrides);
  }

  /// Non-empty trimmed harness overrides ready to send in an update request.
  Map<HarnessId, String> get normalizedHarnessOverrides => <HarnessId, String>{
    for (final entry in harnessOverridesDraft.entries)
      if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
  };

  /// Builds an [UpdateSettingsRequest] from the current draft values.
  UpdateSettingsRequest toUpdateRequest() {
    final trimmedAgents = agentsDirDraft.trim();
    final agentsDir =
        trimmedAgents.isEmpty || trimmedAgents == saved.defaultAgentsDir
        ? null
        : trimmedAgents;
    return UpdateSettingsRequest(
      agentsDir: agentsDir,
      harnessOverrides: normalizedHarnessOverrides,
    );
  }

  static bool _mapsEqual(Map<HarnessId, String> a, Map<HarnessId, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
