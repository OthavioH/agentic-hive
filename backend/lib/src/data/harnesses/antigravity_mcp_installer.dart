import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/mcp_installer_helpers.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [HarnessMcpInstaller] for Antigravity (`agy mcp`).
final class AntigravityMcpInstaller implements HarnessMcpInstaller {
  /// Creates an Antigravity MCP installer.
  const new({
    required this._processRunner,
    this._probeTimeout = defaultMcpProbeTimeout,
    this._installTimeout = defaultMcpInstallTimeout,
  });

  final ProcessRunner _processRunner;
  final Duration _probeTimeout;
  final Duration _installTimeout;

  @override
  HarnessId get id => HarnessId.antigravity;

  @override
  String? get configPath => null;

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
        message: 'Timed out while checking Antigravity MCP status.',
      );
    }
    if (result.launchError != null) {
      return HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Failed to run Antigravity CLI: ${result.launchError}',
      );
    }

    if (result.exitCode != 0) {
      final summary = summarizeProcessOutput(result.stderr, result.stdout);
      return HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: summary.isEmpty
            ? 'Antigravity CLI exited with code ${result.exitCode}.'
            : summary,
      );
    }

    final rowMatch = _hiveRowPattern.firstMatch(result.stdout);
    if (rowMatch != null) {
      final type = rowMatch.group(1)!.trim();
      final status = rowMatch.group(2)!.trim();
      final commandLine = rowMatch.group(3)!.trim();
      if (type == 'stdio' &&
          status == 'enabled' &&
          mcpCommandLineMatches(
            commandLine: commandLine,
            expected: expectedCommand,
          )) {
        return const HarnessMcpDetectionResult(
          status: HarnessMcpStatus.installed,
        );
      }
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.outdated,
        message: 'Configured Antigravity MCP entry is outdated or disabled.',
      );
    }

    if (_tableHeaderPattern.hasMatch(result.stdout)) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.notInstalled,
      );
    }

    return const HarnessMcpDetectionResult(
      status: HarnessMcpStatus.unknown,
      message: 'Could not parse Antigravity MCP list output.',
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
      hiveMcpServerName,
      '--',
      command.executable,
      ...command.baseArguments,
    ], timeout: _installTimeout);

    if (result.timedOut || result.launchError != null || result.exitCode != 0) {
      return mcpInstallCommandFailure(id.displayName, result);
    }
    return const Success<void>(null);
  }

  static final RegExp _hiveRowPattern = RegExp(
    r'^\s*hive\s+(\S+)\s+(\S+)\s+(.+?)\s*$',
    multiLine: true,
  );

  static final RegExp _tableHeaderPattern = RegExp(
    r'^\s*NAME\s+TYPE\s+STATUS\s+COMMAND/URL\b|No MCP servers',
    multiLine: true,
    caseSensitive: false,
  );
}
