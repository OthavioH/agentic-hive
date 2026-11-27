import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/version_bump.dart';

// Bumps the product version in an isolated git worktree on `release/vX.Y.Z`,
// commits the change, pushes the branch, and opens a PR into `development`.
//
// Usage:
//   dart run tool/bump_version.dart <X.Y.Z> [--base <branch>] [--dry-run]

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    stderr.writeln(
      'Usage: dart run tool/bump_version.dart <X.Y.Z> '
      '[--base <branch>] [--dry-run]',
    );
    exitCode = 64;
    return;
  }

  final String version;
  try {
    version = parseSemver(parsed.version);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
    return;
  }

  final repoRoot = await _runChecked('git', const <String>[
    'rev-parse',
    '--show-toplevel',
  ]);
  final branch = 'release/v$version';
  final worktreePath = p.join(
    p.dirname(repoRoot),
    '${p.basename(repoRoot)}-release-v$version',
  );

  if (parsed.dryRun) {
    stdout
      ..writeln('Dry run for version $version:')
      ..writeln('  base:     origin/${parsed.base}')
      ..writeln('  branch:   $branch')
      ..writeln('  worktree: $worktreePath')
      ..writeln('  files:    ${versionTargetFiles.join(', ')}');
    return;
  }

  if (Directory(worktreePath).existsSync()) {
    stderr.writeln('Worktree path already exists: $worktreePath');
    exitCode = 1;
    return;
  }

  await _runChecked('git', <String>['fetch', 'origin', parsed.base]);
  await _runChecked('git', <String>[
    'worktree',
    'add',
    '-b',
    branch,
    worktreePath,
    'origin/${parsed.base}',
  ]);

  bumpVersionInDirectory(worktreePath, version);

  await _runChecked('git', <String>[
    'add',
    ...versionTargetFiles,
  ], workingDirectory: worktreePath);
  await _runChecked('git', <String>[
    'commit',
    '-m',
    'chore: bump product version to $version',
  ], workingDirectory: worktreePath);
  await _runChecked('git', <String>[
    'push',
    '-u',
    'origin',
    branch,
  ], workingDirectory: worktreePath);

  final prUrl = await _runChecked('gh', <String>[
    'pr',
    'create',
    '--base',
    parsed.base,
    '--head',
    branch,
    '--title',
    'chore: bump product version to $version',
    '--body',
    'Bump product version to `$version`.',
  ], workingDirectory: worktreePath);

  stdout
    ..writeln('Created worktree: $worktreePath')
    ..writeln('Branch:           $branch')
    ..writeln('Pull request:     $prUrl');
}

({String version, String base, bool dryRun})? _parseArgs(List<String> args) {
  var base = 'development';
  var dryRun = false;
  String? version;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--base') {
      if (i + 1 >= args.length) return null;
      base = args[++i];
    } else if (arg.startsWith('-')) {
      return null;
    } else {
      if (version != null) return null;
      version = arg;
    }
  }

  if (version == null) return null;
  return (version: version, base: base, dryRun: dryRun);
}

Future<String> _runChecked(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    final err = '${result.stderr}'.trim();
    final out = '${result.stdout}'.trim();
    final details = err.isNotEmpty ? err : out;
    throw ProcessException(executable, arguments, details, result.exitCode);
  }
  return '${result.stdout}'.trim();
}
