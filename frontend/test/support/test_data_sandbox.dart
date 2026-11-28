import 'dart:io';

import 'package:path/path.dart' as p;

/// Redirects `dart:io` access under [dataDir] into [sandboxRoot].
///
/// Installed globally by `test/flutter_test_config.dart` so tests never read
/// or write the real user data folder (issue #149).
final class SandboxIOOverrides extends IOOverrides {
  /// Creates overrides that redirect paths under [dataDir] into [sandboxRoot]
  /// using [context] for platform-aware path comparison.
  ///
  /// Paths equal to or within any entry of [excludedDirs] are left untouched
  /// (for example, the `worktrees` subfolder when tests run from a worktree).
  new({
    required this.dataDir,
    required this.sandboxRoot,
    required this.context,
    this.excludedDirs = const [],
  });

  /// The real user data folder (e.g. `%LOCALAPPDATA%\AgenticHive`).
  final String dataDir;

  /// The temporary directory where redirected paths are stored.
  final String sandboxRoot;

  /// Platform path context used for comparisons and joins.
  final p.Context context;

  /// Directories under [dataDir] whose paths are never redirected.
  final List<String> excludedDirs;

  @override
  File createFile(String path) => super.createFile(_redirect(path));

  @override
  Directory createDirectory(String path) =>
      super.createDirectory(_redirect(path));

  String _redirect(String path) {
    for (final excluded in excludedDirs) {
      if (context.equals(excluded, path) || context.isWithin(excluded, path)) {
        return path;
      }
    }
    if (context.equals(dataDir, path)) return sandboxRoot;
    if (context.isWithin(dataDir, path)) {
      return context.join(sandboxRoot, context.relative(path, from: dataDir));
    }
    return path;
  }
}
