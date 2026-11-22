import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/mcp_installer_helpers.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [HarnessMcpInstaller] for Google Gemini CLI (`gemini mcp`).
final class GeminiCliMcpInstaller implements HarnessMcpInstaller {
  /// Creates a Gemini CLI MCP installer.
  const new({
    required this._processRunner,
    this._probeTimeout = defaultMcpProbeTimeout,
    this._installTimeout = defaultMcpInstallTimeout,
  });

  final ProcessRunner _processRunner;
  final Duration _probeTimeout;
  final Duration _installTimeout;

  @override
  HarnessId get id => HarnessId.geminiCli;

  @override
  Future<HarnessMcpDetectionResult> detect({
    required String executablePath,
    required HiveMcpLaunchCommand expectedCommand,
  }) async {
    final result = await _processRunner.run(executablePath, const <String>[
      'mcp',
      'list',
    ], timeout: _probeTimeout);

    if (result.timedOut) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Timed out while checking Gemini CLI MCP status.',
      );
    }
    if (result.launchError != null) {
      return HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Failed to run Gemini CLI: ${result.launchError}',
      );
    }

    // Gemini CLI may print validation warnings about unrelated user settings
    // entries on stderr/stdout while still printing Configured MCP servers.
    final combined = '${result.stdout}\n${result.stderr}';
    final entryMatch = _hiveEntryPattern.firstMatch(combined);
    if (entryMatch != null) {
      final commandLine = entryMatch.group(1)!.trim();
      if (mcpCommandLineMatches(
        commandLine: commandLine,
        expected: expectedCommand,
      )) {
        return const HarnessMcpDetectionResult(
          status: HarnessMcpStatus.installed,
        );
      }
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.outdated,
        message: 'Configured Gemini CLI MCP command is outdated.',
      );
    }

    if (result.exitCode == 0 && _listHeaderPattern.hasMatch(combined)) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.notInstalled,
      );
    }

    final summary = summarizeProcessOutput(result.stderr, result.stdout);
    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: summary.isEmpty
          ? 'Could not parse Gemini CLI MCP list output.'
          : summary,
    );
  }

  @override
  Future<Result<void>> install({
    required String executablePath,
    required HiveMcpLaunchCommand command,
  }) async {
    final result = await _processRunner.run(executablePath, <String>[
      'mcp',
      'add',
      '-s',
      'user',
      '--trust',
      hiveMcpServerName,
      command.executable,
      ...command.baseArguments,
    ], timeout: _installTimeout);

    if (result.timedOut || result.launchError != null || result.exitCode != 0) {
      return mcpInstallCommandFailure(id.displayName, result);
    }
    return const Success<void>(null);
  }

  static final RegExp _hiveEntryPattern = RegExp(
    r'^\s*[✓✗✔✖-]?\s*hive:\s*(.+?)\s+\(stdio\)\s+-\s+\w+',
    multiLine: true,
  );

  static final RegExp _listHeaderPattern = RegExp(
    'Configured MCP servers:|No MCP servers configured',
    caseSensitive: false,
  );
}
