import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_repository.dart';
import 'package:agentic_hive_backend/src/domain/settings/workspace_settings_store.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Resolves the execution settings (default isolation mode, snapshot
/// `ignorePatterns`, default shell) of a workspace: its own override wins,
/// an absent key falls back to the global value, and an absent global value
/// falls back to the built-in default (ADR 0025).
///
/// Only these three settings can be overridden per workspace; machine-specific
/// settings (CLI paths, theme) stay global.
abstract interface class ExecutionSettingsService {
  /// The global execution settings as stored (unset fields are `null`).
  Future<Result<ExecutionSettings>> getGlobal();

  /// Replaces the global execution settings.
  Future<Result<ExecutionSettings>> updateGlobal(ExecutionSettings settings);

  /// Overrides of workspace [workspaceId], what it inherits and the result.
  Future<Result<WorkspaceSettingsResponse>> getForWorkspace(String workspaceId);

  /// Replaces the overrides of workspace [workspaceId].
  Future<Result<WorkspaceSettingsResponse>> updateForWorkspace(
    String workspaceId,
    ExecutionSettings overrides,
  );

  /// Effective settings for workspace [workspaceId].
  Future<Result<EffectiveExecutionSettings>> effectiveFor(String workspaceId);
}

/// Default [ExecutionSettingsService]: global values live in the SQLite
/// settings table, workspace overrides in the workspace folder.
final class DefaultExecutionSettingsService
    implements ExecutionSettingsService {
  /// Creates the service.
  const new({
    required this._settings,
    required this._workspaces,
    required this._store,
    required this._shellProvider,
  });

  /// SQLite key for the global default isolation mode.
  static const isolationModeKey = 'execution.default_isolation_mode';

  /// SQLite key for the global snapshot ignore patterns (JSON array).
  static const ignorePatternsKey = 'execution.ignore_patterns';

  /// SQLite key for the global default shell.
  static const defaultShellKey = 'execution.default_shell';

  /// Isolation mode used when neither the workspace nor the global settings
  /// set one.
  static const WorkspaceIsolationMode builtInIsolationMode =
      WorkspaceIsolationMode.worktree;

  final SettingsRepository _settings;
  final WorkspaceRepository _workspaces;
  final WorkspaceSettingsStore _store;
  final DefaultShellProvider _shellProvider;

  @override
  Future<Result<ExecutionSettings>> getGlobal() async {
    final stored = await _settings.getAll();
    return stored.map(_decodeGlobal);
  }

  @override
  Future<Result<ExecutionSettings>> updateGlobal(
    ExecutionSettings settings,
  ) async {
    final invalid = _validate(settings);
    if (invalid != null) return FailureResult(invalid);
    final normalized = _normalize(settings);
    final persisted = await _settings.applyChanges(<String, String?>{
      isolationModeKey: normalized.defaultIsolationMode?.name,
      ignorePatternsKey: normalized.ignorePatterns == null
          ? null
          : jsonEncode(normalized.ignorePatterns),
      defaultShellKey: normalized.defaultShell,
    });
    if (persisted case FailureResult<void>(:final failure)) {
      return FailureResult(failure);
    }
    return await getGlobal();
  }

  @override
  Future<Result<WorkspaceSettingsResponse>> getForWorkspace(
    String workspaceId,
  ) async {
    final workspace = await _workspaces.getById(workspaceId);
    if (workspace case FailureResult<Workspace>(:final failure)) {
      return FailureResult(failure);
    }
    final overrides = await _store.read(workspace.valueOrNull!.rootPath);
    if (overrides case FailureResult<ExecutionSettings>(:final failure)) {
      return FailureResult(failure);
    }
    final global = await getGlobal();
    if (global case FailureResult<ExecutionSettings>(:final failure)) {
      return FailureResult(failure);
    }
    return Success(
      WorkspaceSettingsResponse(
        overrides: overrides.valueOrNull!,
        global: _resolve(global.valueOrNull!, const ExecutionSettings()),
        effective: _resolve(global.valueOrNull!, overrides.valueOrNull!),
      ),
    );
  }

  @override
  Future<Result<WorkspaceSettingsResponse>> updateForWorkspace(
    String workspaceId,
    ExecutionSettings overrides,
  ) async {
    final invalid = _validate(overrides);
    if (invalid != null) return FailureResult(invalid);
    final workspace = await _workspaces.getById(workspaceId);
    if (workspace case FailureResult<Workspace>(:final failure)) {
      return FailureResult(failure);
    }
    final written = await _store.write(
      workspace.valueOrNull!.rootPath,
      _normalize(overrides),
    );
    if (written case FailureResult<void>(:final failure)) {
      return FailureResult(failure);
    }
    return await getForWorkspace(workspaceId);
  }

  @override
  Future<Result<EffectiveExecutionSettings>> effectiveFor(
    String workspaceId,
  ) async {
    final response = await getForWorkspace(workspaceId);
    return response.map((value) => value.effective);
  }

  EffectiveExecutionSettings _resolve(
    ExecutionSettings global,
    ExecutionSettings overrides,
  ) => EffectiveExecutionSettings(
    defaultIsolationMode:
        overrides.defaultIsolationMode ??
        global.defaultIsolationMode ??
        builtInIsolationMode,
    ignorePatterns:
        overrides.ignorePatterns ?? global.ignorePatterns ?? const <String>[],
    defaultShell:
        overrides.defaultShell ??
        global.defaultShell ??
        _shellProvider.defaultShell,
  );

  ExecutionSettings _decodeGlobal(Map<String, String> stored) {
    final mode = stored[isolationModeKey];
    final patterns = stored[ignorePatternsKey];
    final shell = stored[defaultShellKey]?.trim();
    return ExecutionSettings(
      defaultIsolationMode: mode == null
          ? null
          : WorkspaceIsolationMode.fromName(mode),
      ignorePatterns: patterns == null
          ? null
          : (jsonDecode(patterns) as List<Object?>).cast<String>(),
      defaultShell: (shell == null || shell.isEmpty) ? null : shell,
    );
  }

  ExecutionSettings _normalize(ExecutionSettings settings) => ExecutionSettings(
    defaultIsolationMode: settings.defaultIsolationMode,
    ignorePatterns: settings.ignorePatterns
        ?.map((pattern) => pattern.trim())
        .toList(),
    defaultShell: settings.defaultShell?.trim(),
  );

  Failure? _validate(ExecutionSettings settings) {
    final errors = <String, String>{};
    final shell = settings.defaultShell;
    if (shell != null && shell.trim().isEmpty) {
      errors['defaultShell'] = 'Default shell must not be blank.';
    }
    final patterns = settings.ignorePatterns;
    if (patterns != null && patterns.any((entry) => entry.trim().isEmpty)) {
      errors['ignorePatterns'] = 'Ignore patterns must not be blank.';
    }
    if (errors.isEmpty) return null;
    return ValidationFailure(
      'Execution settings validation failed.',
      details: errors,
    );
  }
}
