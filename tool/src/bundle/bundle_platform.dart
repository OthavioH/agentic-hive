import 'package:path/path.dart' as p;

/// File naming of the Bundle on one operating system (ADR 0012).
abstract interface class BundlePlatform {
  /// Path rules of this platform.
  p.Context get context;

  /// File name of an executable called [name] (`server` -> `server.exe` on
  /// Windows).
  String executableFileName(String name);

  /// File name of the SQLite library that `dart build cli` puts in `lib/`.
  String get sqliteLibraryFileName;
}

/// Creates the [BundlePlatform] for [operatingSystem] (a
/// `Platform.operatingSystem` value).
BundlePlatform bundlePlatformFor(String operatingSystem) =>
    switch (operatingSystem) {
      'windows' => const WindowsBundlePlatform(),
      'linux' => const LinuxBundlePlatform(),
      'macos' => const MacOSBundlePlatform(),
      _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
    };

/// [BundlePlatform] for Windows.
final class WindowsBundlePlatform implements BundlePlatform {
  /// Creates a [WindowsBundlePlatform].
  const new();

  @override
  p.Context get context => p.windows;

  @override
  String executableFileName(String name) => '$name.exe';

  @override
  String get sqliteLibraryFileName => 'sqlite3.dll';
}

/// [BundlePlatform] for Linux.
final class LinuxBundlePlatform implements BundlePlatform {
  /// Creates a [LinuxBundlePlatform].
  const new();

  @override
  p.Context get context => p.posix;

  @override
  String executableFileName(String name) => name;

  @override
  String get sqliteLibraryFileName => 'libsqlite3.so';
}

/// [BundlePlatform] for macOS.
///
/// Not verified: macOS is built in CI but not released.
final class MacOSBundlePlatform implements BundlePlatform {
  /// Creates a [MacOSBundlePlatform].
  const new();

  @override
  p.Context get context => p.posix;

  @override
  String executableFileName(String name) => name;

  @override
  String get sqliteLibraryFileName => 'libsqlite3.dylib';
}
