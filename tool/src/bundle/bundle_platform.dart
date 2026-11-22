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

  /// File name of the compiled program of [entryPoint] that `dart build cli`
  /// puts in `lib/`, or `null` when the executable is self-contained.
  ///
  /// On Linux `bin/<entryPoint>` is a small runtime that loads
  /// `../lib/libdartaot<entryPoint>.so` by its own file name, so executables
  /// must not be renamed.
  String? aotLibraryFileName(String entryPoint);
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

  @override
  // `dart build cli` makes self-contained `.exe` files on Windows.
  String? aotLibraryFileName(String entryPoint) => null;
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

  @override
  String? aotLibraryFileName(String entryPoint) => 'libdartaot$entryPoint.so';
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

  @override
  // Not verified: macOS is built in CI but not released.
  String? aotLibraryFileName(String entryPoint) =>
      'libdartaot$entryPoint.dylib';
}
