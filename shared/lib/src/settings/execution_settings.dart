import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workspace/workspace_isolation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'execution_settings.freezed.dart';
part 'execution_settings.g.dart';

/// Execution settings that exist globally and can be overridden per workspace
/// (ADR 0022).
///
/// Every field is optional: `null` means "not set here", so a workspace falls
/// back to the global value and the global value falls back to the built-in
/// default. CLI paths and theme are machine-specific and are deliberately not
/// part of this type.
@freezed
sealed class ExecutionSettings with _$ExecutionSettings {
  /// Creates execution settings; omitted fields are inherited.
  const factory({
    WorkspaceIsolationMode? defaultIsolationMode,
    List<String>? ignorePatterns,
    String? defaultShell,
  }) = _ExecutionSettings;

  const new _();

  /// Decodes execution settings; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$ExecutionSettingsFromJson);

  /// JSON keys a workspace may override. Anything else is machine-specific.
  static const overridableKeys = <String>{
    'defaultIsolationMode',
    'ignorePatterns',
    'defaultShell',
  };

  /// Whether no field is set.
  bool get isEmpty =>
      defaultIsolationMode == null &&
      ignorePatterns == null &&
      defaultShell == null;
}

/// Execution settings after fallback resolution: every field has a value.
@freezed
sealed class EffectiveExecutionSettings with _$EffectiveExecutionSettings {
  /// Creates resolved execution settings.
  const factory({
    required WorkspaceIsolationMode defaultIsolationMode,
    required List<String> ignorePatterns,
    required String defaultShell,
  }) = _EffectiveExecutionSettings;

  /// Decodes resolved settings; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$EffectiveExecutionSettingsFromJson);
}

/// Body of `GET`/`PUT /api/v1/workspaces/{id}/settings`.
///
/// [overrides] are the values stored in the workspace, [global] is what the
/// workspace would inherit without them, and [effective] is the result.
@freezed
sealed class WorkspaceSettingsResponse with _$WorkspaceSettingsResponse {
  /// Creates a workspace settings response.
  const factory({
    required ExecutionSettings overrides,
    required EffectiveExecutionSettings global,
    required EffectiveExecutionSettings effective,
  }) = _WorkspaceSettingsResponse;

  /// Decodes a workspace settings response; throws a [FormatException] on a
  /// bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkspaceSettingsResponseFromJson);
}
