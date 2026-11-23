import 'dart:io';

import 'package:path/path.dart' as p;

/// Operating-system-specific paths for locating the local backend.
///
/// Everything that differs between Windows, Linux and macOS lives behind this
/// interface; the rest of the frontend never branches on the platform inline.
///
/// Follows ADR 0012 and must stay in sync with
/// `backend/lib/src/config/platform_paths.dart`, since `frontend/` and
/// `backend/` never import each other.
abstract interface class PlatformPaths {
  /// Path rules of this platform.
  p.Context get context;

  /// The folder where the backend keeps its database, logs, config and socket.
  String defaultDataDir();

  /// Path to the `server.json` file written by the running backend.
  String serverInfoPath() => context.join(defaultDataDir(), 'server.json');
}

/// Creates the [PlatformPaths] for [operatingSystem] (a value of
/// `Platform.operatingSystem`).
PlatformPaths platformPathsFor(
  String operatingSystem, {
  required Map<String, String> environment,
}) => switch (operatingSystem) {
  'windows' => WindowsPaths(environment),
  'linux' => LinuxPaths(environment),
  'macos' => MacOSPaths(environment),
  _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
};

/// The [PlatformPaths] of the running process.
PlatformPaths currentPlatformPaths() => platformPathsFor(
  Platform.operatingSystem,
  environment: Platform.environment,
);

/// Windows: `%LOCALAPPDATA%\AgenticHive`.
final class WindowsPaths extends PlatformPaths {
  /// Creates the Windows paths from the process [_environment].
  new(this._environment);

  final Map<String, String> _environment;

  @override
  p.Context get context => p.windows;

  @override
  String defaultDataDir() =>
      context.join(_requireEnv(_environment, 'LOCALAPPDATA'), 'AgenticHive');
}

/// Linux: `$XDG_DATA_HOME/agentic-hive`, or `~/.local/share/agentic-hive`.
final class LinuxPaths extends PlatformPaths {
  /// Creates the Linux paths from the process [_environment].
  new(this._environment);

  final Map<String, String> _environment;

  @override
  p.Context get context => p.posix;

  @override
  String defaultDataDir() {
    final xdgDataHome = _environment['XDG_DATA_HOME'];
    final base = xdgDataHome != null && context.isAbsolute(xdgDataHome)
        ? xdgDataHome
        : context.join(_requireEnv(_environment, 'HOME'), '.local', 'share');
    return context.join(base, 'agentic-hive');
  }
}

/// macOS: `~/Library/Application Support/AgenticHive`.
final class MacOSPaths extends PlatformPaths {
  /// Creates the macOS paths from the process [_environment].
  new(this._environment);

  final Map<String, String> _environment;

  @override
  p.Context get context => p.posix;

  @override
  String defaultDataDir() => context.join(
    _requireEnv(_environment, 'HOME'),
    'Library',
    'Application Support',
    'AgenticHive',
  );
}

String _requireEnv(Map<String, String> environment, String name) {
  final value = environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('The $name environment variable is not set.');
  }
  return value;
}
