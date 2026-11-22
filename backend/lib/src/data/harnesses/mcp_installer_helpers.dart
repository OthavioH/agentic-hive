import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:path/path.dart' as p;

/// Checks whether a configured [command] and [args] match [expected].
bool mcpCommandMatches({
  required String command,
  required List<String> args,
  required HiveMcpLaunchCommand expected,
  p.Context? pathContext,
}) {
  final ctx = pathContext ?? p.context;
  if (!_sameSegment(command.trim(), expected.executable.trim(), ctx)) {
    return false;
  }
  if (args.length != expected.baseArguments.length) {
    return false;
  }
  for (var i = 0; i < args.length; i++) {
    if (!_sameSegment(args[i].trim(), expected.baseArguments[i].trim(), ctx)) {
      return false;
    }
  }
  return true;
}

/// Checks whether a single flattened command-line string matches [expected].
bool mcpCommandLineMatches({
  required String commandLine,
  required HiveMcpLaunchCommand expected,
  p.Context? pathContext,
}) {
  final ctx = pathContext ?? p.context;
  final expectedFull = <String>[
    expected.executable,
    ...expected.baseArguments,
  ].map((part) => _normalizeIfPath(part.trim(), ctx)).join(' ');
  final actualNormalized = commandLine
      .trim()
      .split(RegExp(r'\s+'))
      .map((part) => _normalizeIfPath(part, ctx))
      .join(' ');
  return actualNormalized == expectedFull;
}

/// Summarizes a failed CLI [ProcessRunResult] as a [HarnessMcpInstallFailure].
FailureResult<void> mcpInstallCommandFailure(
  String displayName,
  ProcessRunResult result, {
  String action = 'install',
}) {
  if (result.timedOut) {
    return FailureResult(
      HarnessMcpInstallFailure(
        'Timed out while running $displayName CLI to $action Hive MCP.',
      ),
    );
  }
  if (result.launchError != null) {
    return FailureResult(
      HarnessMcpInstallFailure(
        'Failed to start $displayName CLI: ${result.launchError}',
      ),
    );
  }
  final detail = summarizeProcessOutput(result.stderr, result.stdout);
  final suffix = detail.isEmpty ? '' : ': $detail';
  return FailureResult(
    HarnessMcpInstallFailure(
      '$displayName CLI exited with code ${result.exitCode}$suffix',
    ),
  );
}

/// Extracts a concise single-line summary from [stderr] or [stdout].
String summarizeProcessOutput(String stderr, String stdout) {
  final raw = stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim();
  if (raw.isEmpty) return '';
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return '';
  final joined = lines.take(3).join(' ');
  return joined.length > 240 ? '${joined.substring(0, 237)}...' : joined;
}

bool _sameSegment(String a, String b, p.Context ctx) =>
    _normalizeIfPath(a, ctx) == _normalizeIfPath(b, ctx);

String _normalizeIfPath(String value, p.Context ctx) {
  if (value.contains('/') || value.contains(r'\')) {
    return ctx.normalize(value);
  }
  return value;
}
