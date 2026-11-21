import 'dart:io';

import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';

/// Creates the [DefaultShellProvider] for [operatingSystem]
/// (`Platform.operatingSystem`).
DefaultShellProvider defaultShellProviderFor(String operatingSystem) =>
    switch (operatingSystem) {
      'windows' => const WindowsShellProvider(),
      'linux' || 'macos' => const PosixShellProvider(),
      _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
    };

/// The [DefaultShellProvider] for the current operating system.
DefaultShellProvider currentDefaultShellProvider() =>
    defaultShellProviderFor(Platform.operatingSystem);

/// Windows default shell (`COMSPEC` or `cmd.exe`).
final class WindowsShellProvider implements DefaultShellProvider {
  /// Creates a Windows shell provider.
  const new();

  @override
  String get defaultShell {
    final comspec = Platform.environment['COMSPEC']?.trim();
    return (comspec != null && comspec.isNotEmpty) ? comspec : 'cmd.exe';
  }
}

/// POSIX default shell (`SHELL` or `/bin/sh`).
final class PosixShellProvider implements DefaultShellProvider {
  /// Creates a POSIX shell provider.
  const new();

  @override
  String get defaultShell {
    final shell = Platform.environment['SHELL']?.trim();
    return (shell != null && shell.isNotEmpty) ? shell : '/bin/sh';
  }
}
