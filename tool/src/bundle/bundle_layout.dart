import 'package:path/path.dart' as p;

import 'bundle_platform.dart';

/// Where every file of an assembled Bundle must be.
final class BundleLayout {
  /// Creates a [BundleLayout] rooted at [root] for [platform].
  new(this.root, {required this.platform});

  /// Base name of the Flutter desktop executable.
  static const appName = 'agentic_hive';

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

  /// All files required for a valid bundle, in check order.
  List<String> get requiredFiles => [
    appExecutablePath,
    serverPath,
    hiveMcpPath,
    sqliteLibraryPath,
  ];

  /// Required files for which [fileExists] is false, in [requiredFiles]
  /// order.
  List<String> missingFiles(bool Function(String path) fileExists) =>
      requiredFiles.where((path) => !fileExists(path)).toList();
}
