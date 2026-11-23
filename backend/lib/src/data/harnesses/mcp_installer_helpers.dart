import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Resolves the current user's home directory from [environment].
String? resolveUserHomePath([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final home = env['USERPROFILE'] ?? env['HOME'];
  if (home == null || home.trim().isEmpty) return null;
  return home.trim();
}

/// Reads `mcpServers.hive` from a JSON user config file at [configPath] and
/// compares it against [expectedCommand].
///
/// Used where the CLI's `mcp get`/`mcp list` subcommand health-checks servers
/// and times out under parallel startup load (ADR 0020).
Future<HarnessMcpDetectionResult> detectMcpFromJsonConfig({
  required String? configPath,
  required String displayName,
  required HiveMcpLaunchCommand expectedCommand,
  required Duration timeout,
  required p.Context pathContext,
}) async {
  if (configPath == null) {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: 'Could not locate user home directory for $displayName.',
    );
  }

  final file = File(configPath);
  if (!file.existsSync()) {
    return const HarnessMcpDetectionResult(
      status: HarnessMcpStatus.notInstalled,
    );
  }

  final String raw;
  try {
    raw = await file.readAsString().timeout(timeout);
  } on TimeoutException {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: 'Timed out while reading $displayName MCP configuration.',
    );
  } on FileSystemException catch (e) {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: 'Failed to read $displayName MCP configuration: ${e.message}',
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: 'Could not parse $displayName MCP configuration.',
    );
  }

  if (decoded is! Map<String, Object?>) {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: 'Unexpected $displayName MCP configuration shape.',
    );
  }

  final servers = decoded['mcpServers'];
  if (servers == null) {
    return const HarnessMcpDetectionResult(
      status: HarnessMcpStatus.notInstalled,
    );
  }
  if (servers is! Map<String, Object?>) {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: 'Unexpected $displayName mcpServers configuration shape.',
    );
  }

  final entry = servers[hiveMcpServerName];
  if (entry == null) {
    return const HarnessMcpDetectionResult(
      status: HarnessMcpStatus.notInstalled,
    );
  }
  if (entry is! Map<String, Object?>) {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: 'Unexpected $displayName $hiveMcpServerName MCP entry shape.',
    );
  }

  final type = entry['type'];
  if (type is String && type != 'stdio') {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.outdated,
      message: 'Configured $displayName MCP entry is not a stdio server.',
    );
  }
  if (entry['disabled'] == true || entry['enabled'] == false) {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.outdated,
      message: 'Configured $displayName MCP entry is disabled.',
    );
  }

  final command = entry['command'];
  final rawArgs = entry['args'];
  if (command is! String) {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.outdated,
      message: 'Configured $displayName MCP entry is missing a stdio command.',
    );
  }
  final List<String> args;
  if (rawArgs == null) {
    args = const <String>[];
  } else if (rawArgs is List<Object?>) {
    args = rawArgs.whereType<String>().toList();
    if (args.length != rawArgs.length) {
      return HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: '$displayName MCP args contain non-string values.',
      );
    }
  } else {
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: '$displayName MCP args have an unexpected shape.',
    );
  }

  if (mcpCommandMatches(
    command: command,
    args: args,
    expected: expectedCommand,
    pathContext: pathContext,
  )) {
    return const HarnessMcpDetectionResult(status: HarnessMcpStatus.installed);
  }

  return HarnessMcpDetectionResult(
    status: HarnessMcpStatus.outdated,
    message: 'Configured $displayName MCP command is outdated.',
  );
}

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
