import 'dart:io';

import '../src/hive/hive_io.dart';
import '../src/hive/spec_input.dart';
import '../src/hive/wave_plan.dart';

// First node of the "Spec Implementation" workflow (a harness.terminal node
// in command mode).
//
//   dart run tool/hive/spec_setup.dart [--base <branch>] [<spec number>]
//
// Reads the spec number from the run input (HIVE_PROMPT_FILE) unless one is
// given, pushes the run's target folder to `spec/<n>`, opens (or reuses) the
// draft spec PR against the base branch (default `development`), saves the
// state the later nodes read, and reports the spec's tickets. Safe to re-run.

Future<void> main(List<String> args) async {
  final baseAt = args.indexOf('--base');
  final base = baseAt >= 0 ? args[baseAt + 1] : 'development';
  final positional = [
    for (var i = 0; i < args.length; i++)
      if (i != baseAt && i != baseAt + 1) args[i],
  ];
  try {
    final spec = positional.isNotEmpty
        ? int.parse(positional.first.replaceAll('#', ''))
        : _specFromPrompt();
    if (spec == null) {
      await report(
        success: false,
        summary:
            'No spec number in the run input. Start the run with the spec '
            'issue number, for example "100".',
      );
      return;
    }
    await _setUp(spec, base);
  } on CommandFailed catch (e) {
    await report(success: false, summary: '$e');
  }
}

int? _specFromPrompt() {
  final path = Platform.environment['HIVE_PROMPT_FILE'];
  if (path == null) return null;
  return specNumberFromPrompt(File(path).readAsStringSync());
}

Future<void> _setUp(int spec, String base) async {
  final title = await runText('gh', [
    'issue',
    'view',
    '$spec',
    '--json',
    'title',
    '--jq',
    '.title',
  ]);
  final tickets = await fetchTickets(spec);
  if (tickets.isEmpty) {
    await report(
      success: false,
      summary:
          'Spec #$spec has no sub-issues. Link its tickets as sub-issues '
          'first.',
    );
    return;
  }

  final branch = 'spec/$spec';
  await run('git', ['fetch', 'origin']);
  final remote = await run('git', [
    'ls-remote',
    '--exit-code',
    '--heads',
    'origin',
    branch,
  ], allowFailure: true);
  if (remote.exitCode == 0) {
    await run('git', ['pull', '--ff-only', 'origin', branch]);
  } else {
    await run('git', [
      'commit',
      '--allow-empty',
      '-m',
      'chore: start spec #$spec implementation',
    ]);
  }
  await run('git', ['push', '-u', 'origin', 'HEAD:refs/heads/$branch']);

  final pr = await _openSpecPr(spec, branch, base);
  await SpecState(
    spec: spec,
    title: title,
    branch: branch,
    base: base,
    pr: pr,
  ).write();

  final plan = planWave(tickets, await fetchPullRequests(branch));
  await report(
    success: true,
    summary:
        'Spec #$spec "$title": branch $branch, draft PR #$pr into $base, '
        '${tickets.length} tickets.\n${plan.describe()}',
    data: {
      'spec': spec,
      'title': title,
      'branch': branch,
      'base': base,
      'pr': pr,
      'tickets': [
        for (final t in tickets)
          {
            'number': t.number,
            'title': t.title,
            'status': plan.statuses[t.number]!.name,
          },
      ],
    },
  );
}

Future<int> _openSpecPr(int spec, String branch, String base) async {
  final existing = await runText('gh', [
    'pr',
    'list',
    '--head',
    branch,
    '--base',
    base,
    '--state',
    'open',
    '--json',
    'number',
    '--jq',
    '.[0].number // empty',
  ]);
  if (existing.isNotEmpty) return int.parse(existing);

  const note = 'The Spec Implementation workflow fills in this description.';
  final url = await runText('gh', [
    'pr',
    'create',
    '--draft',
    '--base',
    base,
    '--head',
    branch,
    '--title',
    'Spec #$spec implementation',
    '--body',
    'Part of #$spec.\n\n$note',
  ]);
  return int.parse(url.split('/').last);
}
