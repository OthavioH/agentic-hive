import 'dart:io';

import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// A configuration file that cannot be used. The backend stops on it.
final class ConfigException implements Exception {
  /// Creates the exception with a message that names the bad key or file.
  const new(this.message);

  /// What is wrong, including the file and key involved.
  final String message;

  @override
  String toString() => 'Invalid configuration: $message';
}

/// Builds the [AppConfig] from defaults, an optional YAML file and command-line
/// overrides, in that order of precedence (later wins).
///
/// File lookup:
/// - `--config <path>` when given (it must exist);
/// - otherwise `config/dev.yaml` of the backend package in development;
/// - otherwise `<default data dir>/config.yaml` in production.
/// A missing default file means "use the defaults".
final class ConfigLoader {
  /// Creates a loader for [mode] on the platform described by
  /// [platformPaths].
  new({
    required this.mode,
    required this.platformPaths,
    this.devConfigCandidates = const [],
  });

  /// Decides which file is looked up by default.
  final RuntimeMode mode;

  /// Gives the default data folder.
  final PlatformPaths platformPaths;

  /// Possible locations of `config/dev.yaml`; the first that exists is used.
  final List<String> devConfigCandidates;

  /// Loads and validates the configuration.
  ///
  /// [configPath] comes from `--config`; [dataDirOverride] from `--data-dir`.
  /// Throws a [ConfigException] for anything invalid.
  Future<AppConfig> load({String? configPath, String? dataDirOverride}) async {
    final file = await _resolveFile(configPath);
    final values = file == null ? const _FileValues() : await _parse(file);

    final dataDir = dataDirOverride != null
        ? p.absolute(dataDirOverride)
        : values.dataDir ?? platformPaths.defaultDataDir();

    return AppConfig(
      mode: mode,
      dataDir: p.normalize(dataDir),
      webSocketPingInterval: values.pingIntervalSeconds == null
          ? AppConfig.defaultPingInterval
          : Duration(seconds: values.pingIntervalSeconds!),
      logRetentionDays:
          values.logRetentionDays ?? AppConfig.defaultLogRetentionDays,
    );
  }

  Future<File?> _resolveFile(String? configPath) async {
    if (configPath != null) {
      final file = File(configPath);
      if (!file.existsSync()) {
        throw ConfigException('config file not found: ${file.absolute.path}');
      }
      return file;
    }
    final candidates = mode == RuntimeMode.development
        ? devConfigCandidates
        : [p.join(platformPaths.defaultDataDir(), 'config.yaml')];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) return file;
    }
    return null;
  }

  Future<_FileValues> _parse(File file) async {
    final source = file.absolute.path;
    final Object? document;
    try {
      document = loadYaml(await file.readAsString(), sourceUrl: file.uri);
    } on YamlException catch (e) {
      throw ConfigException('$source is not valid YAML: ${e.message}');
    }
    if (document == null) return const _FileValues();
    if (document is! YamlMap) {
      throw ConfigException('$source must contain a YAML mapping.');
    }

    final root = _Section(document, '', source)
      ..allowOnly(const {'paths', 'websocket', 'logs'});

    final paths = root.section('paths')..allowOnly(const {'data_dir'});
    final websocket = root.section('websocket')
      ..allowOnly(const {'ping_interval_seconds'});
    final logs = root.section('logs')..allowOnly(const {'retention_days'});

    final rawDataDir = paths.string('data_dir');
    return _FileValues(
      dataDir: rawDataDir == null
          ? null
          : p.normalize(p.join(file.absolute.parent.path, rawDataDir)),
      pingIntervalSeconds: websocket.intInRange(
        'ping_interval_seconds',
        min: 1,
        max: 300,
      ),
      logRetentionDays: logs.intInRange('retention_days', min: 1, max: 365),
    );
  }
}

final class _FileValues {
  const new({this.dataDir, this.pingIntervalSeconds, this.logRetentionDays});

  final String? dataDir;
  final int? pingIntervalSeconds;
  final int? logRetentionDays;
}

/// A mapping inside the YAML file, with validation that names the exact key.
final class _Section {
  new(this._map, this._prefix, this._source);

  final YamlMap? _map;
  final String _prefix;
  final String _source;

  String _key(String name) => _prefix.isEmpty ? name : '$_prefix.$name';

  void allowOnly(Set<String> keys) {
    for (final key in _map?.keys ?? const <Object?>[]) {
      if (!keys.contains(key)) {
        throw ConfigException(
          'unknown key "${_key('$key')}" in $_source. '
          'Allowed: ${keys.map(_key).join(', ')}.',
        );
      }
    }
  }

  _Section section(String name) {
    final value = _map?[name];
    if (value == null) return _Section(null, _key(name), _source);
    if (value is! YamlMap) {
      throw ConfigException('"${_key(name)}" must be a mapping in $_source.');
    }
    return _Section(value, _key(name), _source);
  }

  String? string(String name) {
    final value = _map?[name];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw ConfigException(
        '"${_key(name)}" must be a non-empty string in $_source.',
      );
    }
    return value;
  }

  int? intInRange(String name, {required int min, required int max}) {
    final value = _map?[name];
    if (value == null) return null;
    if (value is! int || value < min || value > max) {
      throw ConfigException(
        '"${_key(name)}" must be an integer from $min to $max in $_source.',
      );
    }
    return value;
  }
}
