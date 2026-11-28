import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pty_platform.g.dart';

/// What the backend's PTY looks like on this operating system.
///
/// The backend always runs on the same machine as the app (ADR 0011), so the
/// app's OS decides it; no `shared/` or wire change (ADR 0031, ADR 0012).
abstract interface class PtyPlatform {
  /// Whether the backend's PTY is a Windows ConPTY.
  bool get usesConPty;
}

/// Creates the [PtyPlatform] for [operatingSystem] (a value of
/// `Platform.operatingSystem`).
PtyPlatform ptyPlatformFor(String operatingSystem) => switch (operatingSystem) {
  'windows' => const WindowsPtyPlatform(),
  'linux' => const LinuxPtyPlatform(),
  'macos' => const MacOSPtyPlatform(),
  _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
};

/// The [PtyPlatform] of the running process.
PtyPlatform currentPtyPlatform() => ptyPlatformFor(Platform.operatingSystem);

/// Windows PTY platform (ConPTY).
final class WindowsPtyPlatform implements PtyPlatform {
  /// Creates a [WindowsPtyPlatform].
  const new();

  @override
  bool get usesConPty => true;
}

/// Linux PTY platform (POSIX PTY).
final class LinuxPtyPlatform implements PtyPlatform {
  /// Creates a [LinuxPtyPlatform].
  const new();

  @override
  bool get usesConPty => false;
}

/// macOS PTY platform (POSIX PTY).
final class MacOSPtyPlatform implements PtyPlatform {
  /// Creates a [MacOSPtyPlatform].
  const new();

  @override
  bool get usesConPty => false;
}

/// The [PtyPlatform] of the running process. Tests override it.
@Riverpod(keepAlive: true)
PtyPlatform ptyPlatform(Ref ref) => currentPtyPlatform();
