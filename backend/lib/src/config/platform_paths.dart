import 'dart:io';

import 'package:path/path.dart' as p;

/// Operating-system-specific locations and file-permission rules.
///
/// Everything that differs between Windows, Linux and macOS lives behind this
/// interface; the rest of the backend never checks the platform itself.
abstract interface class PlatformPaths {
  /// Path rules of this platform.
  p.Context get context;

  /// The folder where the backend keeps its database, logs, config and socket.
  String defaultDataDir();

  /// The longest Unix domain socket path, in bytes, this platform accepts.
  int get maxSocketPathBytes;

  /// Makes [directory] accessible to the current user only.
  Future<void> restrictToOwner(String directory);
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

/// Windows: `%LOCALAPPDATA%\AgenticHive`. The user profile's ACL already
/// restricts it to the owner.
final class WindowsPaths implements PlatformPaths {
  /// Creates the Windows paths from the process [_environment].
  new(this._environment);

  final Map<String, String> _environment;

  @override
  p.Context get context => p.windows;

  @override
  String defaultDataDir() =>
      context.join(_requireEnv(_environment, 'LOCALAPPDATA'), 'AgenticHive');

  @override
  int get maxSocketPathBytes => 107;

  @override
  Future<void> restrictToOwner(String directory) async {
    // Folders under %LOCALAPPDATA% inherit an owner-only ACL. Directories
    // given through --data-dir are the user's responsibility.
  }
}

/// Linux: `$XDG_DATA_HOME/agentic-hive`, or `~/.local/share/agentic-hive`.
final class LinuxPaths with _PosixPermissions implements PlatformPaths {
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

  @override
  int get maxSocketPathBytes => 107;
}

/// macOS: `~/Library/Application Support/AgenticHive`.
final class MacOSPaths with _PosixPermissions implements PlatformPaths {
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

  @override
  int get maxSocketPathBytes => 103;
}

mixin _PosixPermissions {
  Future<void> restrictToOwner(String directory) async {
    final result = await Process.run('chmod', ['700', directory]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Could not restrict the data folder to its owner: ${result.stderr}',
        directory,
      );
    }
  }
}

String _requireEnv(Map<String, String> environment, String name) {
  final value = environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('The $name environment variable is not set.');
  }
  return value;
}
