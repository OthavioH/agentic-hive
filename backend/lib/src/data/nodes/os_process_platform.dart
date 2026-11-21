import 'dart:io';

import 'package:path/path.dart' as p;

/// OS-specific process launching and process-tree termination abstraction.
///
/// Isolates Windows vs Linux vs macOS differences so `DartProcessRunner` never
/// branches on `Platform.isWindows` inline (ADR 0012).
abstract interface class OsProcessPlatform {
  /// Starts [executable] with [arguments].
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  });

  /// Terminates [process] and any descendant child processes.
  Future<void> terminateTree(Process process);
}

/// Creates the [OsProcessPlatform] for [operatingSystem]
/// (`Platform.operatingSystem`).
OsProcessPlatform processPlatformFor(String operatingSystem) =>
    switch (operatingSystem) {
      'windows' => const WindowsProcessPlatform(),
      'linux' => const LinuxProcessPlatform(),
      'macos' => const MacosProcessPlatform(),
      _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
    };

/// The [OsProcessPlatform] for the current operating system.
OsProcessPlatform currentProcessPlatform() =>
    processPlatformFor(Platform.operatingSystem);

/// Windows process launcher and `taskkill /F /T /PID` tree terminator.
final class WindowsProcessPlatform implements OsProcessPlatform {
  /// Creates a Windows process platform.
  const new();

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final lower = executable.toLowerCase();
    if (lower.endsWith('.cmd') || lower.endsWith('.bat')) {
      return await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        runInShell: true,
      );
    }

    try {
      return await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } on ProcessException {
      if (await _hasWindowsBatchShim(executable, workingDirectory)) {
        return await Process.start(
          executable,
          arguments,
          workingDirectory: workingDirectory,
          environment: environment,
          runInShell: true,
        );
      }
      rethrow;
    }
  }

  Future<bool> _hasWindowsBatchShim(
    String executable,
    String? workingDirectory,
  ) async {
    try {
      final result = await Process.run('where', <String>[
        executable,
      ], workingDirectory: workingDirectory);
      if (result.exitCode != 0) return false;
      final output = result.stdout as String;
      for (final line in output.split(RegExp(r'\r?\n'))) {
        final lower = line.trim().toLowerCase();
        if (lower.endsWith('.cmd') || lower.endsWith('.bat')) {
          return true;
        }
      }
      return false;
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<void> terminateTree(Process process) async {
    try {
      await Process.run('taskkill', <String>[
        '/F',
        '/T',
        '/PID',
        '${process.pid}',
      ]);
    } on ProcessException {
      process.kill(ProcessSignal.sigkill);
    }
  }
}

/// Base POSIX (Linux and macOS) process platform that spawns each child as the
/// leader of its own process group (`pgid == pid`) and terminates the entire
/// process group with `kill(-pid, SIGKILL)` on timeout (ADR 0012).
abstract base class PosixProcessPlatform implements OsProcessPlatform {
  /// Creates a POSIX process platform.
  const new();

  /// Verifies [executable] exists before launching a process-group wrapper so
  /// missing executables throw [ProcessException] immediately.
  void ensureExecutableExists(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    final trimmed = executable.trim();
    if (trimmed.isEmpty) {
      throw ProcessException(
        executable,
        arguments,
        'Executable path must not be empty',
        2,
      );
    }

    if (trimmed.contains('/')) {
      final resolved = p.posix.isAbsolute(trimmed)
          ? trimmed
          : p.posix.join(workingDirectory ?? Directory.current.path, trimmed);
      if (!File(resolved).existsSync()) {
        throw ProcessException(
          executable,
          arguments,
          'No such file or directory',
          2,
        );
      }
      return;
    }

    final pathEnv = environment?['PATH'] ?? Platform.environment['PATH'] ?? '';
    for (final dir in pathEnv.split(':')) {
      if (dir.isEmpty) continue;
      if (File(p.posix.join(dir, trimmed)).existsSync()) {
        return;
      }
    }
    throw ProcessException(
      executable,
      arguments,
      'No such file or directory',
      2,
    );
  }

  @override
  Future<void> terminateTree(Process process) async {
    try {
      await Process.run('kill', <String>['-KILL', '--', '-${process.pid}']);
    } on ProcessException {
      // Fallback to direct process kill below.
    }
    process.kill(ProcessSignal.sigkill);
  }
}

/// Linux [OsProcessPlatform] that spawns each child in a new session and
/// process group (`pgid == pid`) via `setsid` (which `exec`s in-place because
/// the newly forked child is not yet a process group leader).
final class LinuxProcessPlatform extends PosixProcessPlatform {
  /// Creates a Linux process platform.
  const new();

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    ensureExecutableExists(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    try {
      return await Process.start(
        'setsid',
        <String>[executable, ...arguments],
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } on ProcessException {
      return await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    }
  }
}

/// macOS [OsProcessPlatform] that spawns each child in its own process group
/// (`pgid == pid`) by calling `POSIX::setpgid(0, 0)` and `exec`ing the target
/// binary in-place through `/usr/bin/perl`.
final class MacosProcessPlatform extends PosixProcessPlatform {
  /// Creates a macOS process platform.
  const new();

  static const String _setpgidExecScript =
      r'POSIX::setpgid(0, 0); exec {$ARGV[0]} @ARGV or exit 127';

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    ensureExecutableExists(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    try {
      return await Process.start(
        '/usr/bin/perl',
        <String>['-MPOSIX', '-e', _setpgidExecScript, executable, ...arguments],
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } on ProcessException {
      return await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    }
  }
}
