import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/mcp_installer_helpers.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// [HarnessMcpInstaller] for OpenAI Codex (`codex mcp` + `config.toml`
/// `env_vars`).
final class CodexMcpInstaller implements HarnessMcpInstaller {
  /// Creates a Codex MCP installer.
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
  HarnessId get id => HarnessId.codex;

  @override
  Future<HarnessMcpDetectionResult> detect({
    required String executablePath,
    required HiveMcpLaunchCommand expectedCommand,
  }) async {
    final result = await _processRunner.run(executablePath, const <String>[
      'mcp',
      'get',
      hiveMcpServerName,
      '--json',
    ], timeout: _probeTimeout);

    if (result.timedOut) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Timed out while checking Codex MCP status.',
      );
    }
    if (result.launchError != null) {
      return HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Failed to run Codex CLI: ${result.launchError}',
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
            ? 'Codex CLI exited with code ${result.exitCode}.'
            : summary,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(result.stdout);
    } on FormatException {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Could not parse Codex MCP JSON output.',
      );
    }

    if (decoded is! Map<String, Object?>) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Unexpected Codex MCP JSON shape.',
      );
    }

    final enabled = decoded['enabled'] != false;
    final transport = decoded['transport'];
    if (transport is! Map<String, Object?> || transport['type'] != 'stdio') {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.outdated,
        message: 'Configured Codex MCP entry is not a stdio server.',
      );
    }

    final command = transport['command'];
    final rawArgs = transport['args'];
    if (command is! String || rawArgs is! List<Object?>) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Codex MCP transport is missing command or args.',
      );
    }
    final args = rawArgs.whereType<String>().toList();
    if (args.length != rawArgs.length) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.unknown,
        message: 'Codex MCP args contain non-string values.',
      );
    }

    final rawEnvVars = transport['env_vars'];
    final envVars = rawEnvVars is List<Object?>
        ? rawEnvVars.whereType<String>().toSet()
        : const <String>{};
    final hasAllEnvVars = hiveMcpEnvVarNames.every(envVars.contains);

    if (enabled &&
        hasAllEnvVars &&
        mcpCommandMatches(
          command: command,
          args: args,
          expected: expectedCommand,
          pathContext: _path,
        )) {
      return const HarnessMcpDetectionResult(
        status: HarnessMcpStatus.installed,
      );
    }

    return HarnessMcpDetectionResult(
      status: HarnessMcpStatus.outdated,
      message: hasAllEnvVars
          ? 'Configured Codex MCP command is outdated.'
          : 'Configured Codex MCP entry is missing HIVE_* env_vars.',
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

    return await _ensureEnvVarsInConfigToml();
  }

  Future<Result<void>> _ensureEnvVarsInConfigToml() async {
    final configPath = _resolveConfigPath();
    if (configPath == null) {
      return const FailureResult(
        HarnessMcpInstallFailure(
          'Could not locate user home directory for Codex config.toml.',
        ),
      );
    }

    final file = File(configPath);
    if (!file.existsSync()) {
      return FailureResult(
        HarnessMcpInstallFailure('Codex config file not found at $configPath.'),
      );
    }

    try {
      final original = await file.readAsString();
      final updated = _patchEnvVarsInToml(original);
      if (updated == original) {
        return const Success<void>(null);
      }

      // Back up before modifying, then write atomically via a sibling
      // temp file.
      await file.copy('$configPath.bak');
      final tmpFile = File('$configPath.tmp.$pid');
      await tmpFile.writeAsString(updated);
      await tmpFile.rename(configPath);
      return const Success<void>(null);
    } on FileSystemException catch (e) {
      return FailureResult(
        HarnessMcpInstallFailure(
          'Failed to update Codex config.toml env_vars: ${e.message}',
        ),
      );
    }
  }

  String? _resolveConfigPath() {
    if (_configPathOverride != null) return _configPathOverride;
    final env = Platform.environment;
    final codexHome = env['CODEX_HOME']?.trim();
    if (codexHome != null && codexHome.isNotEmpty) {
      return _path.join(codexHome, 'config.toml');
    }
    final home = env['USERPROFILE'] ?? env['HOME'];
    if (home == null || home.trim().isEmpty) return null;
    return _path.join(home.trim(), '.codex', 'config.toml');
  }

  static String _patchEnvVarsInToml(String source) {
    final lines = const LineSplitter().convert(source);
    final eol = source.contains('\r\n') ? '\r\n' : '\n';
    final envVarsLine =
        'env_vars = [${hiveMcpEnvVarNames.map((k) => '"$k"').join(', ')}]';

    final sectionIndex = lines.indexWhere(
      (line) => line.trim() == '[mcp_servers.$hiveMcpServerName]',
    );
    if (sectionIndex == -1) {
      return source;
    }

    var sectionEnd = lines.length;
    for (var i = sectionIndex + 1; i < lines.length; i++) {
      if (lines[i].trim().startsWith('[')) {
        sectionEnd = i;
        break;
      }
    }

    final envVarsIndex = lines.indexWhere(
      _envVarsKeyPattern.hasMatch,
      sectionIndex + 1,
    );
    if (envVarsIndex != -1 && envVarsIndex < sectionEnd) {
      lines[envVarsIndex] = envVarsLine;
    } else {
      var insertAt = sectionEnd;
      while (insertAt > sectionIndex + 1 &&
          lines[insertAt - 1].trim().isEmpty) {
        insertAt--;
      }
      lines.insert(insertAt, envVarsLine);
    }

    final trailingNewline = source.endsWith('\n') ? eol : '';
    return '${lines.join(eol)}$trailingNewline';
  }

  static final RegExp _notFoundPattern = RegExp(
    'no mcp server named|not found',
    caseSensitive: false,
  );

  static final RegExp _envVarsKeyPattern = RegExp(r'^\s*env_vars\s*=');
}
