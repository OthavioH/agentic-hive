import 'dart:io';

import 'package:agentic_hive_backend/src/config/config_loader.dart';
import 'package:agentic_hive_backend/src/config/dev_config_candidates.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_backend_client.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_server.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_socket_client.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_socket_resolver.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_tools_client.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:args/args.dart';
import 'package:dart_mcp/stdio.dart';

/// Exit code for invalid CLI arguments or missing context (sysexits).
const _usageError = 64;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('socket', help: 'Path to the backend Unix domain socket.')
    ..addOption('run-id', help: 'Active workflow run ID.')
    ..addOption('node-id', help: 'Active workflow node ID.')
    ..addOption('attempt', help: '1-based node execution attempt number.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exitCode = _usageError;
    return;
  }

  if (args.flag('help')) {
    stderr.writeln('Agentic Hive stdio MCP proxy\n\n${parser.usage}');
    return;
  }

  final env = Platform.environment;
  final socketPath =
      _nonEmpty(args.option('socket')) ?? _nonEmpty(env['HIVE_SOCKET_PATH']);
  final runId =
      _nonEmpty(args.option('run-id')) ?? _nonEmpty(env['HIVE_RUN_ID']);
  final nodeId =
      _nonEmpty(args.option('node-id')) ?? _nonEmpty(env['HIVE_NODE_ID']);
  final attemptRaw =
      _nonEmpty(args.option('attempt')) ?? _nonEmpty(env['HIVE_ATTEMPT']);

  final HiveMcpBackendClient? client;
  if (socketPath == null ||
      runId == null ||
      nodeId == null ||
      attemptRaw == null) {
    // Outside an Agentic Hive run (for example `claude mcp get hive` or an
    // interactive user session): start the server and answer tool calls with
    // an `isError` message instead of failing startup.
    client = null;
  } else {
    final attempt = int.tryParse(attemptRaw);
    if (attempt == null || attempt < 1) {
      stderr.writeln(
        'Invalid --attempt "$attemptRaw": must be a positive int.',
      );
      exitCode = _usageError;
      return;
    }
    client = HiveMcpBackendClient(
      socketPath: socketPath,
      runId: runId,
      nodeId: nodeId,
      attempt: attempt,
    );
  }

  final resolved = await HiveMcpSocketResolver(
    loadConfig: () => ConfigLoader(
      mode: RuntimeMode.current,
      platformPaths: currentPlatformPaths(),
      devConfigCandidates: [?scriptRelativeDevConfig(Platform.script)],
    ).load(),
  ).resolve(explicitSocket: socketPath);
  final discovered = resolved.valueOrNull;
  final tools = HiveMcpToolsClient(
    socket: discovered == null
        ? null
        : HiveMcpSocketClient(socketPath: discovered),
    cwd: Directory.current.path,
  );

  final server = HiveMcpServer(
    stdioChannel(input: stdin, output: stdout),
    client: client,
    tools: tools,
  );

  await server.done;
}

String? _nonEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
