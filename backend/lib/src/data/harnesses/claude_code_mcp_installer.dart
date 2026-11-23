import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/mcp_installer_helpers.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// [HarnessMcpInstaller] for Claude Code (`~/.claude.json` + `claude mcp`).
final class ClaudeCodeMcpInstaller implements HarnessMcpInstaller {
  /// Creates a Claude Code MCP installer.
  new({
    required this._processRunner,
    this._probeTimeout = defaultMcpProbeTimeout,
    this._installTimeout = defaultMcpInstallTimeout,
    this._configPathOverride,
    p.Context? pathContext,
  }) : _path = pathContext ?? p.context;

  final ProcessRunner _processRunner;
  final Duration _probeTimeout;
  final Duration _installTimeout;
  final String? _configPathOverride;
  final p.Context _path;

  @override
  HarnessId get id => HarnessId.claudeCode;

  @override
  Future<HarnessMcpDetectionResult> detect({
    required String executablePath,
    required HiveMcpLaunchCommand expectedCommand,
  }) => detectMcpFromJsonConfig(
    configPath: _resolveConfigPath(),
    displayName: id.displayName,
    expectedCommand: expectedCommand,
    timeout: _probeTimeout,
    pathContext: _path,
  );

  String? _resolveConfigPath() {
    if (_configPathOverride != null) return _configPathOverride;
    final home = resolveUserHomePath();
    if (home == null) return null;
    return _path.join(home, '.claude.json');
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

  static final RegExp _alreadyExistsPattern = RegExp(
    'already exists',
    caseSensitive: false,
  );
}
