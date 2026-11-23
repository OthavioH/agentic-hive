import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/mcp_installer_helpers.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// [HarnessMcpInstaller] for Google Gemini CLI (`~/.gemini/settings.json` +
/// `gemini mcp`).
final class GeminiCliMcpInstaller implements HarnessMcpInstaller {
  /// Creates a Gemini CLI MCP installer.
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
  HarnessId get id => HarnessId.geminiCli;

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
    return _path.join(home, '.gemini', 'settings.json');
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
}
