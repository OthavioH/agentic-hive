import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/mcp_installer_helpers.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [HarnessMcpInstaller] for Claude Code (`claude mcp`).
final class ClaudeCodeMcpInstaller implements HarnessMcpInstaller {
  /// Creates a Claude Code MCP installer.
  const new({
    required this._processRunner,
    this._probeTimeout = defaultMcpProbeTimeout,
    this._installTimeout = defaultMcpInstallTimeout,
  });

  final ProcessRunner _processRunner;
  final Duration _probeTimeout;
  final Duration _installTimeout;

  @override
  HarnessId get id => HarnessId.claudeCode;

  @override
  Future<HarnessMcpDetectionResult> detect({
    required String executablePath,
    required HiveMcpLaunchCommand expectedCommand,
  }) async {
    final result = await _processRunner.run(executablePath, const <String>[
      'mcp',
      'get',
      hiveMcpServerName,
    ], timeout: _probeTimeout);

    if (result.timedOut) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Timed out while checking Claude Code MCP status.',
      );
    }
    if (result.launchError != null) {
      return HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Failed to run Claude Code CLI: ${result.launchError}',
      );
    }

    final combined = '${result.stdout}\n${result.stderr}';
    if (result.exitCode != 0) {
      if (_notFoundPattern.hasMatch(combined)) {
        return const HarnessMcpDetectionResult(
          status: HarnessMcpStatus.notInstalled,
        );
      }
      final summary = summarizeProcessOutput(result.stderr, result.stdout);
      return HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: summary.isEmpty
            ? 'Claude Code CLI exited with code ${result.exitCode}.'
            : summary,
      );
    }

    final commandMatch = _commandLinePattern.firstMatch(result.stdout);
    if (commandMatch == null) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Could not parse Claude Code MCP configuration.',
      );
    }

    final actualCommand = commandMatch.group(1)!.trim();
    final argsMatch = _argsLinePattern.firstMatch(result.stdout);
    final rawArgs = argsMatch?.group(1)?.trim() ?? '';
    final actualArgs = rawArgs.isEmpty
        ? const <String>[]
        : rawArgs.split(RegExp(r'\s+'));

    if (mcpCommandMatches(
      command: actualCommand,
      args: actualArgs,
      expected: expectedCommand,
    )) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.installed,
      );
    }

    return const HarnessMcpDetectionResult(
      status: HarnessMcpStatus.outdated,
      message: 'Configured Claude Code MCP command is outdated.',
    );
  }

  @override
  Future<Result<void>> install({
    required String executablePath,
    required HiveMcpLaunchCommand command,
  }) async {
    final addArgs = <String>[
      'mcp',
      'add',
      '-s',
      'user',
      hiveMcpServerName,
      '--',
      command.executable,
      ...command.baseArguments,
    ];

    var result = await _processRunner.run(
      executablePath,
      addArgs,
      timeout: _installTimeout,
    );

    if (result.exitCode != 0 &&
        _alreadyExistsPattern.hasMatch('${result.stdout}\n${result.stderr}')) {
      final removeResult = await _processRunner.run(
        executablePath,
        const <String>['mcp', 'remove', '-s', 'user', hiveMcpServerName],
        timeout: _installTimeout,
      );
      if (removeResult.timedOut ||
          removeResult.launchError != null ||
          removeResult.exitCode != 0) {
        return mcpInstallCommandFailure(
          id.displayName,
          removeResult,
          action: 'replace',
        );
      }
      result = await _processRunner.run(
        executablePath,
        addArgs,
        timeout: _installTimeout,
      );
    }

    if (result.timedOut || result.launchError != null || result.exitCode != 0) {
      return mcpInstallCommandFailure(id.displayName, result);
    }
    return const Success<void>(null);
  }

  static final RegExp _notFoundPattern = RegExp(
    r'no mcp server named\s+"?hive"?',
    caseSensitive: false,
  );

  static final RegExp _alreadyExistsPattern = RegExp(
    'already exists',
    caseSensitive: false,
  );

  static final RegExp _commandLinePattern = RegExp(
    r'^\s*Command:\s*(.+)$',
    multiLine: true,
  );

  static final RegExp _argsLinePattern = RegExp(
    r'^\s*Args:\s*(.*)$',
    multiLine: true,
  );
}
