import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_directory_watcher.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/settings/executable_validator.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Manages runtime application settings, atomic validation, SQLite
/// persistence, and live F2/F3 reloads.
abstract interface class SettingsService {
  /// Broadcast stream of updated [AppSettings] snapshots.
  Stream<AppSettings> get settingsUpdates;

  /// Returns the current effective [AppSettings] merged over bootstrap
  /// defaults.
  Future<Result<AppSettings>> getSettings();

  /// Validates [request] atomically, persists changes, triggers live F2/F3
  /// reloads where values changed, and broadcasts `settings.updated`.
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request);

  /// Applies persisted SQLite settings to F2 and F3 on backend startup.
  Future<Result<AppSettings>> applyPersistedSettings();

  /// Releases stream resources.
  Future<void> dispose();
}

/// Default implementation of [SettingsService].
final class DefaultSettingsService implements SettingsService {
  /// Creates a settings service.
  new({
    required this._repository,
    required this._config,
    required this._executableValidator,
    required this._agentRepository,
    required this._agentDirectoryWatcher,
    required this._harnessService,
    p.Context? pathContext,
  }) : _path = pathContext ?? p.context;

  /// SQLite key for the custom agents directory.
  static const agentsDirKey = 'agents_dir';

  /// SQLite key for the default workspace directory.
  static const defaultWorkspaceDirKey = 'default_workspace_dir';

  /// SQLite key prefix for per-harness executable overrides.
  static const harnessOverridePrefix = 'harness_override.';

  final SettingsRepository _repository;
  final AppConfig _config;
  final ExecutableValidator _executableValidator;
  final LocalAgentRepository _agentRepository;
  final AgentDirectoryWatcher _agentDirectoryWatcher;
  final HarnessService _harnessService;
  final p.Context _path;

  final StreamController<AppSettings> _updatesController =
      StreamController<AppSettings>.broadcast();

  String get _defaultAgentsDir => _path.join(_config.dataDir, 'agents');

  @override
  Stream<AppSettings> get settingsUpdates => _updatesController.stream;

  @override
  Future<Result<AppSettings>> getSettings() async {
    final storedResult = await _repository.getAll();
    return storedResult.map(_mergeWithDefaults);
  }

  @override
  Future<Result<AppSettings>> applyPersistedSettings() async {
    final result = await getSettings();
    if (result case Success(:final value)) {
      if (!_path.equals(
        _path.normalize(value.agentsDir),
        _path.normalize(_agentRepository.agentsDir),
      )) {
        await Directory(value.agentsDir).create(recursive: true);
        _agentRepository.agentsDir = value.agentsDir;
        await _agentDirectoryWatcher.switchDirectory(value.agentsDir);
      }
      await _harnessService.applyExecutableOverrides(
        value.harnessOverrides,
        triggerRefresh: false,
      );
    }
    return result;
  }

  @override
  Future<Result<AppSettings>> updateSettings(
    UpdateSettingsRequest request,
  ) async {
    final currentResult = await getSettings();
    final AppSettings current;
    switch (currentResult) {
      case Success(:final value):
        current = value;
      case FailureResult(:final failure):
        return FailureResult(failure);
    }

    final errors = <String, String>{};

    final rawAgentsDir = request.agentsDir?.trim();
    final hasCustomAgentsDir = rawAgentsDir != null && rawAgentsDir.isNotEmpty;
    if (hasCustomAgentsDir) {
      if (!_path.isAbsolute(rawAgentsDir)) {
        errors['agentsDir'] = 'Agents folder must be an absolute path.';
      } else if (!Directory(rawAgentsDir).existsSync()) {
        errors['agentsDir'] = 'Agents folder does not exist.';
      }
    }

    final rawWorkspaceDir = request.defaultWorkspaceDir?.trim();
    final hasWorkspaceDir =
        rawWorkspaceDir != null && rawWorkspaceDir.isNotEmpty;
    if (hasWorkspaceDir) {
      if (!_path.isAbsolute(rawWorkspaceDir)) {
        errors['defaultWorkspaceDir'] =
            'Default workspace must be an absolute path.';
      } else if (!Directory(rawWorkspaceDir).existsSync()) {
        errors['defaultWorkspaceDir'] =
            'Default workspace folder does not exist.';
      }
    }

    final normalizedOverrides = <HarnessId, String>{};
    for (final entry in request.harnessOverrides.entries) {
      final id = entry.key;
      final rawPath = entry.value.trim();
      if (rawPath.isEmpty) continue;

      final fieldKey = 'harnessOverrides.${id.wireName}';
      if (!_path.isAbsolute(rawPath)) {
        errors[fieldKey] = '${id.displayName} path must be an absolute path.';
      } else if (!await _executableValidator.isExecutable(rawPath)) {
        errors[fieldKey] =
            '${id.displayName} path must point to an existing executable file.';
      } else {
        normalizedOverrides[id] = rawPath;
      }
    }

    if (errors.isNotEmpty) {
      return FailureResult(
        ValidationFailure('Settings validation failed.', details: errors),
      );
    }

    final effectiveAgentsDir = hasCustomAgentsDir
        ? rawAgentsDir
        : _defaultAgentsDir;
    if (!hasCustomAgentsDir) {
      await Directory(effectiveAgentsDir).create(recursive: true);
    }

    final changes = <String, String?>{
      agentsDirKey: hasCustomAgentsDir ? rawAgentsDir : null,
      defaultWorkspaceDirKey: hasWorkspaceDir ? rawWorkspaceDir : null,
      for (final id in HarnessId.values)
        '$harnessOverridePrefix${id.wireName}': normalizedOverrides[id],
    };

    final persistResult = await _repository.applyChanges(changes);
    if (persistResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }

    final updated = AppSettings(
      agentsDir: effectiveAgentsDir,
      defaultAgentsDir: _defaultAgentsDir,
      defaultWorkspaceDir: hasWorkspaceDir ? rawWorkspaceDir : null,
      harnessOverrides: normalizedOverrides,
    );

    if (!_path.equals(
      _path.normalize(current.agentsDir),
      _path.normalize(updated.agentsDir),
    )) {
      _agentRepository.agentsDir = updated.agentsDir;
      await _agentDirectoryWatcher.switchDirectory(updated.agentsDir);
    }

    await _harnessService.applyExecutableOverrides(updated.harnessOverrides);

    if (!_updatesController.isClosed) {
      _updatesController.add(updated);
    }

    return Success(updated);
  }

  @override
  Future<void> dispose() => _updatesController.close();

  AppSettings _mergeWithDefaults(Map<String, String> stored) {
    final storedAgentsDir = stored[agentsDirKey]?.trim();
    final agentsDir = (storedAgentsDir != null && storedAgentsDir.isNotEmpty)
        ? storedAgentsDir
        : _config.agentsDir;

    final storedWorkspace = stored[defaultWorkspaceDirKey]?.trim();
    final defaultWorkspaceDir =
        (storedWorkspace != null && storedWorkspace.isNotEmpty)
        ? storedWorkspace
        : null;

    final overrides = <HarnessId, String>{};
    for (final id in HarnessId.values) {
      final raw = stored['$harnessOverridePrefix${id.wireName}']?.trim();
      if (raw != null && raw.isNotEmpty) {
        overrides[id] = raw;
      }
    }

    return AppSettings(
      agentsDir: agentsDir,
      defaultAgentsDir: _defaultAgentsDir,
      defaultWorkspaceDir: defaultWorkspaceDir,
      harnessOverrides: overrides,
    );
  }
}
