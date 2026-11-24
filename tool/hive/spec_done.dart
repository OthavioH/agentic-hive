import 'dart:io';

import '../src/hive/hive_io.dart';
import '../src/hive/wave_plan.dart';

// "All done?" node of the "Spec Implementation" workflow (a command node).
//
//   dart run tool/hive/spec_done.dart
//
// Exits 0 when every ticket of the spec is done (closed, or its PR merged
// into the spec branch), 1 otherwise.

Future<void> main() async {
  final state = await SpecState.read();
  if (state == null) {
    stderr.writeln('No spec state in this folder. Run spec_setup.dart first.');
    exitCode = 1;
    return;
  }
  final plan = planWave(
    await fetchTickets(state.spec),
    await fetchPullRequests(state.branch),
  );
  stdout.writeln(plan.describe());
  exitCode = plan.allDone ? 0 : 1;
}
