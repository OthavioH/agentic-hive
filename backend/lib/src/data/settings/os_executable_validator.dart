import 'dart:io';

import 'package:agentic_hive_backend/src/domain/settings/executable_validator.dart';

/// Creates the [ExecutableValidator] for [operatingSystem]
/// (`Platform.operatingSystem`).
ExecutableValidator executableValidatorFor(String operatingSystem) =>
    switch (operatingSystem) {
      'windows' => const WindowsExecutableValidator(),
      'linux' || 'macos' => const PosixExecutableValidator(),
      _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
    };

/// The [ExecutableValidator] for the current operating system.
ExecutableValidator currentExecutableValidator() =>
    executableValidatorFor(Platform.operatingSystem);

/// Windows executable validator: file must exist and have a runnable extension
/// (`.exe`, `.cmd`, `.bat`, `.com`).
final class WindowsExecutableValidator implements ExecutableValidator {
  /// Creates a Windows executable validator.
  const new();

  @override
  Future<bool> isExecutable(String path) async {
    if (!FileSystemEntity.isFileSync(path)) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.exe') ||
        lower.endsWith('.cmd') ||
        lower.endsWith('.bat') ||
        lower.endsWith('.com');
  }
}

/// POSIX (Linux and macOS) executable validator: file must exist and have at
/// least one execute permission bit (`0111`).
final class PosixExecutableValidator implements ExecutableValidator {
  /// Creates a POSIX executable validator.
  const new();

  @override
  Future<bool> isExecutable(String path) async {
    if (!FileSystemEntity.isFileSync(path)) return false;
    final stat = File(path).statSync();
    return (stat.mode & 0x49) != 0;
  }
}
