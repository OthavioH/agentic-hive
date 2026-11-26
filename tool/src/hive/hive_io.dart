import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'ci_checks.dart';
import 'wave_plan.dart';

/// A command that exited with a non-zero code.
final class CommandFailed implements Exception {
  /// Creates a [CommandFailed].
  const new(this.command, this.exitCode, this.stderr);

  /// The command line that failed.
  final String command;

  /// Its exit code.
  final int exitCode;

  /// Its standard error.
  final String stderr;

  @override
  String toString() => '`$command` exited with $exitCode: ${stderr.trim()}';
}

/// Runs [executable] with [arguments] and returns its stdout. Throws
/// [CommandFailed] on a non-zero exit code unless [allowFailure] is set.
Future<ProcessResult> run(
  String executable,
  List<String> arguments, {
  bool allowFailure = false,
}) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0 && !allowFailure) {
    throw CommandFailed(
      '$executable ${arguments.join(' ')}',
      result.exitCode,
      '${result.stderr}',
    );
  }
  return result;
}

/// Runs [executable] like [run] and returns its trimmed stdout.
Future<String> runText(String executable, List<String> arguments) async =>
    '${(await run(executable, arguments)).stdout}'.trim();

Future<T> _json<T>(String executable, List<String> arguments) async =>
    jsonDecode(await runText(executable, arguments)) as T;

/// State the spec workflow keeps between nodes, in the git directory of the
/// run's target folder (per worktree, never committed).
final class SpecState {
  /// Creates a [SpecState].
  const new({
    required this.spec,
    required this.title,
    required this.branch,
    required this.base,
    required this.pr,
  });

  /// Parses [json].
  factory fromJson(Map<String, Object?> json) => SpecState(
    spec: json['spec']! as int,
    title: json['title']! as String,
    branch: json['branch']! as String,
    base: json['base']! as String,
    pr: json['pr']! as int,
  );

  /// Spec issue number.
  final int spec;

  /// Spec issue title.
  final String title;

  /// Remote spec branch (`spec/<n>`).
  final String branch;

  /// Branch the spec PR targets.
  final String base;

  /// Spec PR number.
  final int pr;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'spec': spec,
    'title': title,
    'branch': branch,
    'base': base,
    'pr': pr,
  };

  static Future<File> _file() async {
    final gitDir = await runText('git', ['rev-parse', '--absolute-git-dir']);
    return File(p.join(gitDir, 'hive-spec.json'));
  }

  /// Reads the state, or null when this folder has none.
  static Future<SpecState?> read() async {
    final file = await _file();
    if (!file.existsSync()) return null;
    return SpecState.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, Object?>,
    );
  }

  /// Writes the state.
  Future<void> write() async {
    await (await _file()).writeAsString(jsonEncode(toJson()));
  }
}

/// The sub-issues of [spec] with their blockers.
Future<List<Ticket>> fetchTickets(int spec) async {
  final subIssues = await _json<List<Object?>>('gh', [
    'api',
    '--paginate',
    'repos/{owner}/{repo}/issues/$spec/sub_issues',
  ]);
  return [
    for (final raw in subIssues.cast<Map<String, Object?>>())
      Ticket(
        number: raw['number']! as int,
        title: raw['title']! as String,
        isOpen: raw['state'] == 'open',
        labels: [
          for (final l in (raw['labels']! as List).cast<Map<String, Object?>>())
            l['name']! as String,
        ],
        blockedBy: await _blockers(raw['number']! as int),
      ),
  ];
}

Future<List<Blocker>> _blockers(int issue) async {
  final view = await _json<Map<String, Object?>>('gh', [
    'issue',
    'view',
    '$issue',
    '--json',
    'blockedBy',
  ]);
  final nodes = (view['blockedBy']! as Map<String, Object?>)['nodes']! as List;
  return [
    for (final n in nodes.cast<Map<String, Object?>>())
      Blocker(number: n['number']! as int, isOpen: n['state'] == 'OPEN'),
  ];
}

/// Every pull request into [base], in any state.
Future<List<PullRequest>> fetchPullRequests(String base) async {
  final prs = await _json<List<Object?>>('gh', [
    'pr',
    'list',
    '--base',
    base,
    '--state',
    'all',
    '--limit',
    '500',
    '--json',
    'number,state,title,body',
  ]);
  return [
    for (final raw in prs.cast<Map<String, Object?>>())
      PullRequest(
        number: raw['number']! as int,
        state: raw['state']! as String,
        title: raw['title']! as String,
        body: raw['body']! as String,
      ),
  ];
}

/// The spec PR when the folder has spec state, otherwise the PR of the
/// current branch.
Future<int> fetchCurrentPr() async =>
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

/// The checks of [pr], or an empty list while GitHub reports none yet.
Future<List<CiCheck>> fetchChecks(int pr) async {
  final result = await run('gh', [
    'pr',
    'checks',
    '$pr',
    '--json',
    'name,bucket,link',
  ], allowFailure: true);
  final out = '${result.stdout}'.trim();
  if (out.isEmpty) {
    if ('${result.stderr}'.contains('no checks reported')) return [];
    throw CommandFailed(
      'gh pr checks $pr',
      result.exitCode,
      '${result.stderr}',
    );
  }
  return [
    for (final raw in (jsonDecode(out) as List).cast<Map<String, Object?>>())
      CiCheck.fromJson(raw),
  ];
}

/// Writes the ADR 0003 result to `HIVE_RESULT_PATH`, or prints it when the
/// script runs outside a node.
Future<void> report({
  required bool success,
  required String summary,
  Map<String, Object?> data = const {},
}) async {
  final json = const JsonEncoder.withIndent('  ').convert({
    'status': success ? 'success' : 'failure',
    'summary': summary,
    'data': data,
  });
  stdout.writeln(summary);
  final path = Platform.environment['HIVE_RESULT_PATH'];
  if (path == null || path.isEmpty) {
    stdout.writeln(json);
  } else {
    await File(path).writeAsString(json);
  }
}
