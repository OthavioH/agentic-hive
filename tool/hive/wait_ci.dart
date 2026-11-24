import 'dart:io';

import '../src/hive/ci_checks.dart';
import '../src/hive/hive_io.dart';

// Waits for the CI of a pull request (a command node).
//
//   dart run tool/hive/wait_ci.dart [--ready]
//
// The PR is the spec PR when the folder has spec state, otherwise the PR of
// the current branch. `--ready` first takes it out of draft. Exits 0 when
// every check passed, 1 when one failed (the failing checks are printed for
// the next node) or when no check starts within 10 minutes.

const _poll = Duration(seconds: 30);
const _noChecksLimit = Duration(minutes: 10);
const _overallLimit = Duration(hours: 2);

Future<void> main(List<String> args) async {
  try {
    final pr =
        (await SpecState.read())?.pr ??
        int.parse(
          await runText('gh', [
            'pr',
            'view',
            '--json',
            'number',
            '--jq',
            '.number',
          ]),
        );
    if (args.contains('--ready')) {
      await run('gh', ['pr', 'ready', '$pr'], allowFailure: true);
    }
    exitCode = await _wait(pr);
  } on CommandFailed catch (e) {
    stderr.writeln('$e');
    exitCode = 1;
  }
}

Future<int> _wait(int pr) async {
  final started = DateTime.now();
  while (true) {
    final checks = await fetchChecks(pr);
    final elapsed = DateTime.now().difference(started);
    switch (ciStateOf(checks)) {
      case .passed:
        stdout.writeln('CI passed on PR #$pr (${checks.length} checks).');
        return 0;
      case .failed:
        stdout
          ..writeln('CI failed on PR #$pr. Failing checks:')
          ..writeAll(
            checks.where(isFailing).map((c) => '- ${c.name}: ${c.link}\n'),
          )
          ..writeln('Read the logs with: gh run view <run id> --log-failed');
        return 1;
      case .pending when checks.isEmpty && elapsed > _noChecksLimit:
        stdout.writeln(
          'No CI check started on PR #$pr within ${_noChecksLimit.inMinutes} '
          'minutes. Check that CI runs on pull requests into its base branch.',
        );
        return 1;
      case .pending when elapsed > _overallLimit:
        stdout.writeln('CI on PR #$pr still running after 2 hours.');
        return 1;
      case .pending:
        await Future<void>.delayed(_poll);
    }
  }
}
