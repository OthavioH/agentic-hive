import 'dart:io';

import '../src/hive/ci_checks.dart';
import '../src/hive/hive_io.dart';
import '../src/hive/wave_plan.dart';

// "Merge wave" node of the "Spec Implementation" workflow (a command node).
//
//   dart run tool/hive/merge_wave.dart
//
// Squash-merges into the spec branch every open ticket PR whose CI passed,
// so the next wave starts from their code. Exits 1 when a ticket PR is left
// open (CI not green, or the merge failed), so the workflow can stop for a
// human.

Future<void> main() async {
  final state = await SpecState.read();
  if (state == null) {
    stderr.writeln('No spec state in this folder. Run spec_setup.dart first.');
    exitCode = 1;
    return;
  }
  final prs = openTicketPullRequests(
    await fetchTickets(state.spec),
    await fetchPullRequests(state.branch),
  );
  final leftOpen = <String>[];
  for (final pr in prs) {
    final ci = ciStateOf(await fetchChecks(pr.number));
    if (ci != CiState.passed) {
      leftOpen.add('#${pr.number} (CI ${ci.name})');
      continue;
    }
    final merge = await run('gh', [
      'pr',
      'merge',
      '${pr.number}',
      '--squash',
    ], allowFailure: true);
    if (merge.exitCode == 0) {
      stdout.writeln('Merged #${pr.number} into ${state.branch}.');
    } else {
      leftOpen.add('#${pr.number} (merge failed: ${'${merge.stderr}'.trim()})');
    }
  }
  if (leftOpen.isEmpty) {
    stdout.writeln('Merged ${prs.length} ticket PRs into ${state.branch}.');
    return;
  }
  stdout.writeln('Ticket PRs left open: ${leftOpen.join('; ')}');
  exitCode = 1;
}
