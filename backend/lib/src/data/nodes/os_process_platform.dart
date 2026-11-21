import 'dart:io';

/// OS-specific process launching and process-tree termination abstraction.
///
/// Isolates Windows vs POSIX differences so `DartProcessRunner` never branches
/// on `Platform.isWindows` inline (ADR 0012).
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
      'linux' || 'macos' => const PosixProcessPlatform(),
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

/// POSIX (Linux and macOS) process launcher and `SIGKILL` terminator.
final class PosixProcessPlatform implements OsProcessPlatform {
  /// Creates a POSIX process platform.
  const new();

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) => Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );

  @override
  Future<void> terminateTree(Process process) async {
    process.kill(ProcessSignal.sigkill);
  }
}
