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
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
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

  /// SQLite key prefix for per-harness executable overrides.
  static const harnessOverridePrefix = 'harness_override.';

  /// SQLite key for the automatic skill install toggle.
  static const autoInstallSkillsKey = 'auto_install_skills';

  static final _log = Logger('settings');

  final SettingsRepository _repository;
  final AppConfig _config;
  final ExecutableValidator _executableValidator;
  final LocalAgentRepository _agentRepository;
  final AgentDirectoryWatcher _agentDirectoryWatcher;
  final HarnessService _harnessService;
  final p.Context _path;

  final StreamController<AppSettings> _updatesController =
      StreamController<AppSettings>.broadcast();
  Future<void> _updateLock = Future<void>.value();

  String get _defaultAgentsDir => _config.agentsDir;

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
    switch (result) {
      case FailureResult(:final failure):
        _log.warning(
          LogEvent(
            'settings.apply_persisted_failed',
            fields: {'message': failure.message},
          ),
        );
        return result;
      case Success(:final value):
        if (value.agentsDir != null &&
            !Directory(value.effectiveAgentsDir).existsSync()) {
          _log.warning(
            LogEvent(
              'settings.custom_agents_dir_missing',
              fields: {
                'agentsDir': value.effectiveAgentsDir,
                'fallbackDir': _defaultAgentsDir,
              },
            ),
          );
          await _ensureDefaultAndSwitch();
        } else if (!_path.equals(
          _path.normalize(value.effectiveAgentsDir),
          _path.normalize(_agentRepository.agentsDir),
        )) {
          try {
            await _agentDirectoryWatcher.switchDirectory(
              value.effectiveAgentsDir,
              createDirectory: value.agentsDir == null,
            );
            _agentRepository.agentsDir = value.effectiveAgentsDir;
          } on Object catch (error, stackTrace) {
            _log.warning(
              LogEvent(
                'settings.switch_agents_dir_failed',
                fields: {'agentsDir': value.effectiveAgentsDir},
              ),
              error,
              stackTrace,
            );
          }
        }
        await _harnessService.applyExecutableOverrides(
          value.harnessOverrides,
          triggerRefresh: false,
        );
        return result;
    }
  }

  Future<void> _ensureDefaultAndSwitch() async {
    try {
      await Directory(_defaultAgentsDir).create(recursive: true);
      _agentRepository.agentsDir = _defaultAgentsDir;
      await _agentDirectoryWatcher.switchDirectory(
        _defaultAgentsDir,
        createDirectory: true,
      );
    } on Object catch (error, stackTrace) {
      _log.warning(
        LogEvent(
          'settings.fallback_agents_dir_failed',
          fields: {'agentsDir': _defaultAgentsDir},
        ),
        error,
        stackTrace,
      );
    }
  }

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _updateLock = _updateLock.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request) =>
      _synchronized(() => _performUpdateSettings(request));

  Future<Result<AppSettings>> _performUpdateSettings(
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

    final customAgentsDir = hasCustomAgentsDir ? rawAgentsDir : null;
    final effectiveAgentsDir = customAgentsDir ?? _defaultAgentsDir;
    if (!hasCustomAgentsDir) {
      await Directory(effectiveAgentsDir).create(recursive: true);
    }

    final autoInstallSkills =
        request.autoInstallSkills ?? current.autoInstallSkills;

    final updated = AppSettings(
      agentsDir: customAgentsDir,
      effectiveAgentsDir: effectiveAgentsDir,
      defaultAgentsDir: _defaultAgentsDir,
      harnessOverrides: normalizedOverrides,
      autoInstallSkills: autoInstallSkills,
    );

    final persistResult = await _repository.applyChanges(_changesFor(updated));
    if (persistResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }

    if (!_path.equals(
      _path.normalize(current.effectiveAgentsDir),
      _path.normalize(updated.effectiveAgentsDir),
    )) {
      try {
        await _agentDirectoryWatcher.switchDirectory(
          updated.effectiveAgentsDir,
          createDirectory: !hasCustomAgentsDir,
        );
        _agentRepository.agentsDir = updated.effectiveAgentsDir;
      } on Object catch (error) {
        _agentRepository.agentsDir = current.effectiveAgentsDir;
        await _repository.applyChanges(_changesFor(current));
        return FailureResult(
          PersistenceFailure(
            'Failed to switch agents directory.',
            cause: error,
          ),
        );
      }
    }

    await _harnessService.applyExecutableOverrides(updated.harnessOverrides);

    if (!_updatesController.isClosed) {
      _updatesController.add(updated);
    }

    return Success(updated);
  }

  Map<String, String?> _changesFor(AppSettings settings) => <String, String?>{
    agentsDirKey: settings.agentsDir,
    for (final id in HarnessId.values)
      '$harnessOverridePrefix${id.wireName}': settings.harnessOverrides[id],
    autoInstallSkillsKey: settings.autoInstallSkills ? 'true' : 'false',
  };

  @override
  Future<void> dispose() => _updatesController.close();

  AppSettings _mergeWithDefaults(Map<String, String> stored) {
    final storedAgentsDir = stored[agentsDirKey]?.trim();
    final customAgentsDir =
        (storedAgentsDir != null && storedAgentsDir.isNotEmpty)
        ? storedAgentsDir
        : null;
    final effectiveAgentsDir = customAgentsDir ?? _defaultAgentsDir;

    final overrides = <HarnessId, String>{};
    for (final id in HarnessId.values) {
      final raw = stored['$harnessOverridePrefix${id.wireName}']?.trim();
      if (raw != null && raw.isNotEmpty) {
        overrides[id] = raw;
      }
    }

    return AppSettings(
      agentsDir: customAgentsDir,
      effectiveAgentsDir: effectiveAgentsDir,
      defaultAgentsDir: _defaultAgentsDir,
      harnessOverrides: overrides,
      autoInstallSkills: stored[autoInstallSkillsKey] != 'false',
    );
  }
}
