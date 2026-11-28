/// One package of the pub workspace and how its tests run.
enum WorkspacePackage {
  /// The workspace root (`tool/` and its tests in `test/`).
  root('.', ['dart', 'test', '-r', 'failures-only']),

  /// `shared/`.
  shared('shared', ['dart', 'test', '-r', 'failures-only']),

  /// `backend/`.
  backend('backend', ['dart', 'test', '-r', 'failures-only']),

  /// `tools/hive_lints/`.
  hiveLints('tools/hive_lints', ['dart', 'test', '-r', 'failures-only']),

  /// `design_system/`, bundled by `very_good test` (about 2x faster); goldens
  /// run on Ubuntu CI only.
  designSystem('design_system', [
    'dart',
    'pub',
    'global',
    'run',
    'very_good_cli:very_good',
    'test',
    '--exclude-tags',
    'golden',
  ]),

  /// `widgetbook/`. One test file, so `very_good test` gains nothing.
  widgetbook('widgetbook', ['flutter', 'test', '-r', 'failures-only']),

  /// `frontend/`. `very_good test` bundles the test files into one entrypoint,
  /// about 6x faster than `flutter test` here; files tagged
  /// `skip_very_good_optimization` still run on their own.
  frontend('frontend', [
    'dart',
    'pub',
    'global',
    'run',
    'very_good_cli:very_good',
    'test',
  ]);

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

/// Picks the base ref from [aheadCounts] (ref to commits of HEAD beyond the
/// merge-base): the fewest commits ahead wins, and on a tie a `spec/*` ref
/// beats the rest, because a ticket branch is cut from its spec branch.
String pickBase(Map<String, int> aheadCounts) {
  final refs = aheadCounts.keys.toList()
    ..sort((a, b) {
      final byCount = aheadCounts[a]!.compareTo(aheadCounts[b]!);
      if (byCount != 0) return byCount;
      return (a.contains('/spec/') ? 0 : 1).compareTo(
        b.contains('/spec/') ? 0 : 1,
      );
    });
  return refs.first;
}
