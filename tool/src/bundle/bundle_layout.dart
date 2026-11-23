import 'package:path/path.dart' as p;

import 'bundle_platform.dart';

/// Where every file of an assembled Bundle must be.
final class BundleLayout {
  /// Creates a [BundleLayout] rooted at [root] for [platform].
  new(this.root, {required this.platform});

  /// Base name of the Flutter desktop executable.
  static const appName = 'agentic_hive';

  /// Entry points built by `dart build cli` into `backend/bin/`.
  static const backendEntryPoints = ['server', 'hive_mcp'];

  /// Absolute path to the bundle root folder.
  final String root;

  /// Platform naming rules for this bundle.
  final BundlePlatform platform;

  p.Context get _ctx => platform.context;

  /// Path to the app executable at the bundle root.
  String get appExecutablePath =>
      _ctx.join(root, platform.executableFileName(appName));

  /// Path to the `backend/` subfolder inside the bundle.
  String get backendDir => _ctx.join(root, 'backend');

  /// Path to the backend server executable.
  String get serverPath =>
      _ctx.join(backendDir, 'bin', platform.executableFileName('server'));

  /// Path to the MCP server executable.
  String get hiveMcpPath =>
      _ctx.join(backendDir, 'bin', platform.executableFileName('hive_mcp'));

  /// Path to the SQLite dynamic library.
  String get sqliteLibraryPath =>
      _ctx.join(backendDir, 'lib', platform.sqliteLibraryFileName);

  /// Path to the compiled program of [entryPoint] in `backend/lib/`, or
  /// `null` when [platform] builds self-contained executables.
  String? aotLibraryPath(String entryPoint) {
    final name = platform.aotLibraryFileName(entryPoint);
    return name == null ? null : _ctx.join(backendDir, 'lib', name);
  }

  /// Files the backend needs, in check order.
  List<String> get backendFiles => [
    serverPath,
    hiveMcpPath,
    sqliteLibraryPath,
    for (final entry in backendEntryPoints) ?aotLibraryPath(entry),
  ];

  /// All files required for a valid bundle, in check order.
  List<String> get requiredFiles => [appExecutablePath, ...backendFiles];

  /// [backendFiles] for which [fileExists] is false, in order.
  List<String> missingBackendFiles(bool Function(String path) fileExists) =>
      backendFiles.where((path) => !fileExists(path)).toList();

  /// Required files for which [fileExists] is false, in [requiredFiles]
  /// order.
  List<String> missingFiles(bool Function(String path) fileExists) =>
      requiredFiles.where((path) => !fileExists(path)).toList();
}
