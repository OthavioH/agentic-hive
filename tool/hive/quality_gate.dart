import 'dart:io';

import 'package:path/path.dart' as p;

import '../src/hive/hive_io.dart';
import '../src/hive/quality_gate_plan.dart';

// Quality gate of the Ticket Implementation workflow (a command node).
//
//   dart run tool/hive/quality_gate.dart [--base <branch>]
//
// Runs the repository's zero-tolerance checks (format, analyze with infos,
// dart fix) and the tests of every package the change touches, compared with
// origin/<base> (default `development`). Runs every step even after a failure
// and prints the tail of each failing step for the implementer. Exits 1 when
// any step fails.

const _tailLines = 60;

Future<void> main(List<String> args) async {
  final baseAt = args.indexOf('--base');
  final base = baseAt >= 0 ? args[baseAt + 1] : 'development';

  await run('git', ['fetch', 'origin', base]);
  final mergeBase = await runText('git', [
    'merge-base',
    'HEAD',
    'origin/$base',
  ]);
  final changed = {
    ...(await runText('git', ['diff', '--name-only', mergeBase])).split('\n'),
    ...(await runText('git', [
      'ls-files',
      '--others',
      '--exclude-standard',
    ])).split('\n'),
  }..remove('');
  stdout.writeln('Changed since origin/$base: ${changed.length} files.');

  final dart = Platform.resolvedExecutable;
  final steps = <(String, String, List<String>, String)>[
    (
      'format',
      dart,
      ['format', '--output=none', '--set-exit-if-changed', '.'],
      '.',
    ),
    ('analyze', dart, ['analyze', '--fatal-infos'], '.'),
    ('dart fix', dart, ['fix', '--dry-run'], '.'),
    for (final pkg in affectedPackages(changed))
      (
        'test ${pkg.folder}',
        pkg.testCommand.first == 'dart' ? dart : 'flutter',
        pkg.testCommand.skip(1).toList(),
        pkg.folder,
      ),
  ];

  final failed = <String>[];
  for (final (label, exe, arguments, folder) in steps) {
    final result = await Process.run(
      exe,
      arguments,
      workingDirectory: p.normalize(folder),
      runInShell: Platform.isWindows && exe == 'flutter',
    );
    final output = '${result.stdout}\n${result.stderr}';
    final ok =
        result.exitCode == 0 &&
        (label != 'dart fix' || output.contains('Nothing to fix!'));
    stdout.writeln('${ok ? 'PASS' : 'FAIL'} $label');
    if (!ok) {
      failed.add(label);
      final lines = output.trim().split('\n');
      stdout.writeln(
        lines
            .skip(lines.length > _tailLines ? lines.length - _tailLines : 0)
            .join('\n'),
      );
    }
  }

  stdout.writeln(
    failed.isEmpty
        ? 'Quality gate passed.'
        : 'Quality gate failed: ${failed.join(', ')}.',
  );
  exitCode = failed.isEmpty ? 0 : 1;
}
