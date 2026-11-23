import 'dart:io';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backend_launcher.g.dart';

/// Environment variable overriding the backend executable path.
const String backendBinEnvVar = 'AGENTIC_HIVE_BACKEND_BIN';

/// Environment variable overriding the Dart backend entrypoint in debug mode.
const String backendEntrypointEnvVar = 'AGENTIC_HIVE_BACKEND_ENTRYPOINT';

/// Resolved command specification to start the local Agentic Hive backend.
@immutable
final class BackendLaunchTarget {
  /// Creates a launch target.
  const new({
    required this.executable,
    this.arguments = const <String>[],
    this.workingDirectory,
  });

  /// Executable path or command name.
  final String executable;

  /// Command-line arguments passed to [executable].
  final List<String> arguments;

  /// Optional working directory for the spawned process.
  final String? workingDirectory;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackendLaunchTarget &&
          other.executable == executable &&
          listEquals(other.arguments, arguments) &&
          other.workingDirectory == workingDirectory;

  @override
  int get hashCode =>
      Object.hash(executable, Object.hashAll(arguments), workingDirectory);
}

/// Callback checking whether a file exists at [path].
typedef FileExistsCheck = bool Function(String path);

/// Callback starting a detached OS process.
typedef DetachedProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  ProcessStartMode mode,
});

/// OS-abstracted launcher for starting the local Agentic Hive backend process
/// when no live backend answers on the local socket (ADR 0012, ADR 0016).
abstract interface class BackendLauncher {
  /// Resolves the backend executable or debug `dart run` command without
  /// spawning any process.
  Result<BackendLaunchTarget> resolveLaunchTarget();

  /// Spawns the backend process in detached mode so it outlives the UI.
  Future<Result<void>> launch();
}

/// Creates the [BackendLauncher] for [operatingSystem] (a value of
/// `Platform.operatingSystem`).
BackendLauncher backendLauncherFor(
  String operatingSystem, {
  required String resolvedExecutable,
  required bool isDebugMode,
  required Map<String, String> environment,
  required String currentDirectory,
  FileExistsCheck? fileExists,
  DetachedProcessStarter? startProcess,
}) => switch (operatingSystem) {
  'windows' => WindowsBackendLauncher(
    resolvedExecutable: resolvedExecutable,
    isDebugMode: isDebugMode,
    environment: environment,
    currentDirectory: currentDirectory,
    fileExists: fileExists,
    startProcess: startProcess,
  ),
  'linux' => LinuxBackendLauncher(
    resolvedExecutable: resolvedExecutable,
    isDebugMode: isDebugMode,
    environment: environment,
    currentDirectory: currentDirectory,
    fileExists: fileExists,
    startProcess: startProcess,
  ),
  'macos' => MacOSBackendLauncher(
    resolvedExecutable: resolvedExecutable,
    isDebugMode: isDebugMode,
    environment: environment,
    currentDirectory: currentDirectory,
    fileExists: fileExists,
    startProcess: startProcess,
  ),
  _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
};

/// The [BackendLauncher] of the running process.
BackendLauncher currentBackendLauncher() => backendLauncherFor(
  Platform.operatingSystem,
  resolvedExecutable: Platform.resolvedExecutable,
  isDebugMode: kDebugMode,
  environment: Platform.environment,
  currentDirectory: Directory.current.path,
);

/// Shared implementation of [BackendLauncher] parameterized by OS-specific
/// path conventions and binary names.
abstract base class ProcessBackendLauncher implements BackendLauncher {
  /// Creates a launcher with injectable filesystem and process hooks.
  new({
    required this.resolvedExecutable,
    required this.isDebugMode,
    required this.environment,
    required this.currentDirectory,
    FileExistsCheck? fileExists,
    DetachedProcessStarter? startProcess,
  }) : _fileExists = fileExists ?? _defaultFileExists,
       _startProcess = startProcess ?? _defaultStartProcess;

  /// Path to the running Flutter desktop executable.
  final String resolvedExecutable;

  /// Whether the app is running in debug mode (`kDebugMode`).
  final bool isDebugMode;

  /// Process environment variables.
  final Map<String, String> environment;

  /// Current working directory of the Flutter process.
  final String currentDirectory;

  final FileExistsCheck _fileExists;
  final DetachedProcessStarter _startProcess;

  /// Path rules of this operating system.
  p.Context get context;

  /// Backend server filename inside the Bundle's `backend/bin/` folder.
  String get bundledServerBinaryName;

  /// Dart CLI executable name used in debug mode fallback.
  String get dartExecutable;

  @override
  Result<BackendLaunchTarget> resolveLaunchTarget() {
    final binaryOverride = environment[backendBinEnvVar]?.trim();
    if (binaryOverride != null && binaryOverride.isNotEmpty) {
      if (_fileExists(binaryOverride)) {
        return Success(BackendLaunchTarget(executable: binaryOverride));
      }
      return FailureResult(
        NotFoundFailure(
          'Configured backend binary not found at $binaryOverride.',
        ),
      );
    }

    final bundledServer = context.join(
      context.dirname(resolvedExecutable),
      'backend',
      'bin',
      bundledServerBinaryName,
    );
    if (_fileExists(bundledServer)) {
      return Success(BackendLaunchTarget(executable: bundledServer));
    }

    if (isDebugMode) {
      final entrypointOverride = environment[backendEntrypointEnvVar]?.trim();
      if (entrypointOverride != null && entrypointOverride.isNotEmpty) {
        if (_fileExists(entrypointOverride)) {
          return Success(
            BackendLaunchTarget(
              executable: dartExecutable,
              arguments: <String>['run', entrypointOverride],
              workingDirectory: _backendPackageDir(entrypointOverride),
            ),
          );
        }
        return FailureResult(
          NotFoundFailure(
            'Configured backend entrypoint not found at $entrypointOverride.',
          ),
        );
      }

      for (final candidate in _debugEntrypointCandidates()) {
        if (_fileExists(candidate)) {
          return Success(
            BackendLaunchTarget(
              executable: dartExecutable,
              arguments: <String>['run', candidate],
              workingDirectory: _backendPackageDir(candidate),
            ),
          );
        }
      }
    }

    return FailureResult(
      NotFoundFailure('Backend executable not found at $bundledServer.'),
    );
  }

  @override
  Future<Result<void>> launch() async {
    final targetResult = resolveLaunchTarget();
    if (targetResult case FailureResult<BackendLaunchTarget>(:final failure)) {
      return FailureResult(failure);
    }
    final target = (targetResult as Success<BackendLaunchTarget>).value;

    try {
      await _startProcess(
        target.executable,
        target.arguments,
        workingDirectory: target.workingDirectory,
        mode: ProcessStartMode.detached,
      );
      return const Success(null);
    } on ProcessException catch (error) {
      return FailureResult(
        NotFoundFailure(
          'Failed to start backend process (${target.executable}): '
          '${error.message}',
        ),
      );
    } on Object catch (error) {
      return FailureResult(
        UnexpectedFailure(
          'Unexpected error starting backend process.',
          cause: error,
        ),
      );
    }
  }

  List<String> _debugEntrypointCandidates() => <String>[
    context.join(currentDirectory, 'backend', 'bin', 'server.dart'),
    context.join(
      context.dirname(currentDirectory),
      'backend',
      'bin',
      'server.dart',
    ),
  ];

  String _backendPackageDir(String entrypointPath) =>
      context.dirname(context.dirname(entrypointPath));

  static bool _defaultFileExists(String path) => File(path).existsSync();

  static Future<Process> _defaultStartProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    ProcessStartMode mode = ProcessStartMode.detached,
  }) => Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: mode,
  );
}

/// Windows [BackendLauncher] (`backend\bin\server.exe` / `dart.exe`).
final class WindowsBackendLauncher extends ProcessBackendLauncher {
  /// Creates a Windows backend launcher.
  new({
    required super.resolvedExecutable,
    required super.isDebugMode,
    required super.environment,
    required super.currentDirectory,
    super.fileExists,
    super.startProcess,
  });

  @override
  p.Context get context => p.windows;

  @override
  String get bundledServerBinaryName => 'server.exe';

  @override
  String get dartExecutable => 'dart.exe';
}

/// Linux [BackendLauncher] (`backend/bin/server` / `dart`).
final class LinuxBackendLauncher extends ProcessBackendLauncher {
  /// Creates a Linux backend launcher.
  new({
    required super.resolvedExecutable,
    required super.isDebugMode,
    required super.environment,
    required super.currentDirectory,
    super.fileExists,
    super.startProcess,
  });

  @override
  p.Context get context => p.posix;

  @override
  String get bundledServerBinaryName => 'server';

  @override
  String get dartExecutable => 'dart';
}

/// macOS [BackendLauncher] (`backend/bin/server` / `dart`).
final class MacOSBackendLauncher extends ProcessBackendLauncher {
  /// Creates a macOS backend launcher.
  new({
    required super.resolvedExecutable,
    required super.isDebugMode,
    required super.environment,
    required super.currentDirectory,
    super.fileExists,
    super.startProcess,
  });

  @override
  p.Context get context => p.posix;

  @override
  String get bundledServerBinaryName => 'server';

  @override
  String get dartExecutable => 'dart';
}

/// Provides the OS-appropriate [BackendLauncher].
///
/// Tests can override this provider with a fake [BackendLauncher].
@Riverpod(keepAlive: true)
BackendLauncher backendLauncher(Ref ref) => currentBackendLauncher();
