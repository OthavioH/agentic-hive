import 'dart:io';

import 'package:path/path.dart' as p;

import '../src/hive/hive_io.dart';
import '../src/hive/quality_gate_plan.dart';

// Quality gate of the Ticket Implementation workflow (a command node).
//
//   dart run tool/hive/quality_gate.dart [--base <ref>]
//
// Runs the repository's zero-tolerance checks (format, analyze with infos,
// dart fix) and the tests of every package the change touches, compared with
// the base: `--base <branch>` (origin/<branch>) or, by default, the nearest
// of origin/development and origin/spec/* (fewest commits ahead). Runs every
// step even after a failure
// and prints the tail of each failing step for the implementer. Exits 1 when
// any step fails.

const _tailLines = 120;

Future<void> main(List<String> args) async {
  final baseAt = args.indexOf('--base');
  final String base;
  final String mergeBase;
  if (baseAt >= 0) {
    base = 'origin/${args[baseAt + 1]}';
    await run('git', ['fetch', 'origin', args[baseAt + 1]]);
    mergeBase = await runText('git', ['merge-base', 'HEAD', base]);
    stdout.writeln('Base: $base.');
  } else {
    await run('git', ['fetch', 'origin', '--prune'], allowFailure: true);
    final refs = [
      'origin/development',
      ...(await runText('git', [
        'for-each-ref',
        '--format=%(refname:short)',
        'refs/remotes/origin/spec',
      ])).split('\n').where((r) => r.isNotEmpty),
    ];
    final mergeBases = <String, String>{};
    final ahead = <String, int>{};
    for (final ref in refs) {
      final found = await run('git', [
        'merge-base',
        'HEAD',
        ref,
      ], allowFailure: true);
      if (found.exitCode != 0) continue;
      mergeBases[ref] = '${found.stdout}'.trim();
      ahead[ref] = int.parse(
        await runText('git', [
          'rev-list',
          '--count',
          '${mergeBases[ref]}..HEAD',
        ]),
      );
    }
    base = pickBase(ahead);
    mergeBase = mergeBases[base]!;
    stdout.writeln('Base: $base (${ahead[base]} commits ahead).');
  }
  final changed = {
    ...(await runText('git', ['diff', '--name-only', mergeBase])).split('\n'),
    ...(await runText('git', [
      'ls-files',
      '--others',
      '--exclude-standard',
    ])).split('\n'),
  }..remove('');
  stdout.writeln('Changed since $base: ${changed.length} files.');

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
