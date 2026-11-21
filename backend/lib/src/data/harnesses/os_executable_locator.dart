import 'dart:io';

import 'package:agentic_hive_backend/src/domain/harnesses/executable_locator.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';

/// Default timeout for `where` / `which` binary lookups.
const _lookupTimeout = Duration(seconds: 3);

/// Creates the [ExecutableLocator] for [operatingSystem]
/// (`Platform.operatingSystem`).
ExecutableLocator executableLocatorFor(
  String operatingSystem, {
  required ProcessRunner processRunner,
  Duration timeout = _lookupTimeout,
}) => switch (operatingSystem) {
  'windows' => WindowsExecutableLocator(
    processRunner: processRunner,
    timeout: timeout,
  ),
  'linux' || 'macos' => PosixExecutableLocator(
    processRunner: processRunner,
    timeout: timeout,
  ),
  _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
};

/// The [ExecutableLocator] for the current operating system.
ExecutableLocator currentExecutableLocator(ProcessRunner processRunner) =>
    executableLocatorFor(
      Platform.operatingSystem,
      processRunner: processRunner,
    );

/// Windows binary locator using `where`.
final class WindowsExecutableLocator implements ExecutableLocator {
  /// Creates a Windows locator.
  const new({required this._processRunner, this._timeout = _lookupTimeout});

  final ProcessRunner _processRunner;
  final Duration _timeout;

  @override
  Future<String?> locate(String executableName) async {
    final result = await _processRunner.run('where', [
      executableName,
    ], timeout: _timeout);
    if (result.timedOut || result.launchError != null || result.exitCode != 0) {
      return null;
    }
    for (final rawLine in result.stdout.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isNotEmpty) return line;
    }
    return null;
  }
}

/// POSIX (Linux and macOS) binary locator using `which`.
final class PosixExecutableLocator implements ExecutableLocator {
  /// Creates a POSIX locator.
  const new({required this._processRunner, this._timeout = _lookupTimeout});

  final ProcessRunner _processRunner;
  final Duration _timeout;

  @override
  Future<String?> locate(String executableName) async {
    final result = await _processRunner.run('which', [
      executableName,
    ], timeout: _timeout);
    if (result.timedOut || result.launchError != null || result.exitCode != 0) {
      return null;
    }
    for (final rawLine in result.stdout.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isNotEmpty) return line;
    }
    return null;
  }
}
