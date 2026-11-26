import 'dart:io';

import '../src/hive/ci_checks.dart';
import '../src/hive/hive_io.dart';

// Re-runs failed GitHub Actions workflow runs of a pull request (a command
// node).
//
//   dart run tool/hive/rerun_ci.dart
//
// The PR is the spec PR when the folder has spec state, otherwise the PR of
// the current branch. Finds failing or cancelled checks, de-duplicates their
// workflow run ids, and runs `gh run rerun <id> --failed` for each. Exits 0
// when at least one re-run started, 1 otherwise.

Future<void> main() async {
  try {
    final pr = await fetchCurrentPr();
    final checks = await fetchChecks(pr);
    final runIds = failingRunIds(checks);
    if (runIds.isEmpty) {
      stdout.writeln(
        'No failing or cancelled workflow runs to re-run on PR #$pr.',
      );
      exitCode = 1;
      return;
    }
    var started = 0;
    for (final id in runIds) {
      final result = await run('gh', [
        'run',
        'rerun',
        id,
        '--failed',
      ], allowFailure: true);
      if (result.exitCode == 0) {
        started++;
        stdout.writeln('Re-ran failed jobs of workflow run $id on PR #$pr.');
      } else {
        stderr.writeln(
          'Could not re-run workflow run $id on PR #$pr: '
          '${'${result.stderr}'.trim()}',
        );
      }
    }
    if (started == 0) {
      stdout.writeln('No workflow run could be re-run for PR #$pr.');
      exitCode = 1;
    }
  } on CommandFailed catch (e) {
    stderr.writeln('$e');
    exitCode = 1;
  }
}
