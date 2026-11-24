import 'dart:convert';
import 'dart:io';

import '../src/hive/hive_io.dart';
import '../src/hive/ticket_items.dart';
import '../src/hive/wave_plan.dart';

// "Next wave" node of the "Spec Implementation" workflow (a harness.terminal
// node in command mode).
//
//   dart run tool/hive/next_wave.dart
//
// Reports the tickets that can start now as fan-out items (`data.items`).
// Reports an empty list when every ticket is done, and a failure when tickets
// remain but none can start (a blocker failed, or a ticket PR is still open).
// Label overrides come from tool/hive/ticket_overrides.json.

const _overridesFile = 'tool/hive/ticket_overrides.json';

Future<void> main() async {
  try {
    final state = await SpecState.read();
    if (state == null) {
      await report(
        success: false,
        summary: 'No spec state in this folder. Run spec_setup.dart first.',
      );
      return;
    }
    final plan = planWave(
      await fetchTickets(state.spec),
      await fetchPullRequests(state.branch),
    );
    if (plan.allDone) {
      await report(
        success: true,
        summary: 'Every ticket of spec #${state.spec} is done.',
        data: {'items': <Object?>[]},
      );
      return;
    }
    final startable = plan.withStatus(.startable);
    if (startable.isEmpty) {
      await report(
        success: false,
        summary: 'Tickets remain but none can start:\n${plan.describe()}',
      );
      return;
    }
    final overrides = File(_overridesFile).existsSync()
        ? jsonDecode(File(_overridesFile).readAsStringSync())
              as Map<String, Object?>
        : const <String, Object?>{};
    await report(
      success: true,
      summary:
          'Next wave: ${startable.map((t) => '#${t.number}').join(', ')}.\n'
          '${plan.describe()}',
      data: {
        'items': ticketItems(
          spec: state.spec,
          specBranch: state.branch,
          tickets: startable,
          labelOverrides: overrides,
        ),
      },
    );
  } on CommandFailed catch (e) {
    await report(success: false, summary: '$e');
  }
}
