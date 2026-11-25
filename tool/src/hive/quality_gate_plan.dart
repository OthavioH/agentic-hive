/// One package of the pub workspace and how its tests run.
enum WorkspacePackage {
  /// The workspace root (`tool/` and its tests in `test/`).
  root('.', ['dart', 'test']),

  /// `shared/`.
  shared('shared', ['dart', 'test']),

  /// `backend/`.
  backend('backend', ['dart', 'test']),

  /// `tools/hive_lints/`.
  hiveLints('tools/hive_lints', ['dart', 'test']),

  /// `design_system/`; goldens run on Ubuntu CI only.
  designSystem('design_system', [
    'flutter',
    'test',
    '--exclude-tags',
    'golden',
  ]),

  /// `widgetbook/`.
  widgetbook('widgetbook', ['flutter', 'test']),

  /// `frontend/`.
  frontend('frontend', ['flutter', 'test']);

  new(this.folder, this.testCommand);

  /// Folder relative to the workspace root.
  final String folder;

  /// Test command, executable first.
  final List<String> testCommand;
}

/// Packages whose tests must run when [changedPaths] (relative, `/`
/// separated) change: each changed package plus the packages that depend on
/// it. Paths outside any package (docs, agents, CI files) need no tests.
Set<WorkspacePackage> affectedPackages(Iterable<String> changedPaths) {
  final affected = <WorkspacePackage>{};
  for (final path in changedPaths) {
    final top = path.split('/').first;
    affected.addAll(switch (top) {
      'shared' => const [
        WorkspacePackage.shared,
        WorkspacePackage.backend,
        WorkspacePackage.frontend,
      ],
      'backend' => const [WorkspacePackage.backend],
      'frontend' => const [WorkspacePackage.frontend],
      'design_system' => const [
        WorkspacePackage.designSystem,
        WorkspacePackage.widgetbook,
        WorkspacePackage.frontend,
      ],
      'widgetbook' => const [WorkspacePackage.widgetbook],
      'tools' when path.startsWith('tools/hive_lints/') => const [
        WorkspacePackage.hiveLints,
      ],
      'tool' || 'test' => const [WorkspacePackage.root],
      _ => const <WorkspacePackage>[],
    });
  }
  return affected;
}
