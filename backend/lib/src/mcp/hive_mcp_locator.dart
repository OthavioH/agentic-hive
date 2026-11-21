import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:path/path.dart' as p;

/// Command and base arguments required to launch `hive-mcp`.
final class HiveMcpLaunchCommand {
  /// Creates a launch command.
  const new({required this.executable, this.baseArguments = const <String>[]});

  /// Executable path or name (for example `hive-mcp.exe` or `dart`).
  final String executable;

  /// Leading arguments before `--socket`, `--run-id`, etc. (for example
  /// `['run', '/path/to/bin/hive_mcp.dart']` in development mode).
  final List<String> baseArguments;

  /// Returns full CLI arguments for the given execution context.
  List<String> argumentsFor({
    required String socketPath,
    required String runId,
    required String nodeId,
    required int attempt,
  }) => <String>[
    ...baseArguments,
    '--socket',
    socketPath,
    '--run-id',
    runId,
    '--node-id',
    nodeId,
    '--attempt',
    attempt.toString(),
  ];
}

/// OS-specific companion binary names for `hive-mcp` (ADR 0012).
abstract interface class OsMcpBinaryNaming {
  /// Candidate companion executable filenames next to the backend binary.
  List<String> get companionFileNames;
}

/// Creates the [OsMcpBinaryNaming] for [operatingSystem].
OsMcpBinaryNaming mcpBinaryNamingFor(String operatingSystem) =>
    switch (operatingSystem) {
      'windows' => const _WindowsMcpBinaryNaming(),
      'linux' || 'macos' => const _PosixMcpBinaryNaming(),
      _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
    };

final class _WindowsMcpBinaryNaming implements OsMcpBinaryNaming {
  const new();

  @override
  List<String> get companionFileNames => const <String>[
    'hive-mcp.exe',
    'hive_mcp.exe',
  ];
}

final class _PosixMcpBinaryNaming implements OsMcpBinaryNaming {
  const new();

  @override
  List<String> get companionFileNames => const <String>['hive-mcp', 'hive_mcp'];
}

/// Discovers how to launch `hive-mcp` in production (companion binary next to
/// the backend executable) or development (`dart run bin/hive_mcp.dart`).
final class HiveMcpLocator {
  /// Creates a locator with explicit platform/filesystem hooks for testing.
  new({
    OsMcpBinaryNaming? binaryNaming,
    String? resolvedExecutable,
    bool Function(String path)? fileExists,
    this._scriptPathOverride,
    this._overrideCommand,
    p.Context? pathContext,
  }) : _binaryNaming =
           binaryNaming ?? mcpBinaryNamingFor(Platform.operatingSystem),
       _resolvedExecutable = resolvedExecutable ?? Platform.resolvedExecutable,
       _fileExists = fileExists ?? _defaultFileExists,
       _path = pathContext ?? p.context;

  final OsMcpBinaryNaming _binaryNaming;
  final String _resolvedExecutable;
  final bool Function(String path) _fileExists;
  final String? _scriptPathOverride;
  final HiveMcpLaunchCommand? _overrideCommand;
  final p.Context _path;

  static bool _defaultFileExists(String path) => File(path).existsSync();

  /// Resolves the command used to start `hive-mcp`.
  ///
  /// Falls back to `dart run <script>` only when running under the `dart`
  /// executable in development or when a script/command override is explicitly
  /// configured. Returns a [NodeExecutionFailure] when running as a compiled
  /// a compiled binary with no companion `hive-mcp` executable next to it.
  Result<HiveMcpLaunchCommand> resolve() {
    if (_overrideCommand != null) {
      return Success(_overrideCommand);
    }

    final executableDir = _path.dirname(_resolvedExecutable);
    for (final fileName in _binaryNaming.companionFileNames) {
      final candidate = _path.join(executableDir, fileName);
      if (_fileExists(candidate)) {
        return Success(HiveMcpLaunchCommand(executable: candidate));
      }
    }

    final isDartExecutable =
        _path.basenameWithoutExtension(_resolvedExecutable).toLowerCase() ==
        'dart';
    if (!isDartExecutable && _scriptPathOverride == null) {
      return FailureResult(
        NodeExecutionFailure(
          'Could not locate companion hive-mcp executable next to '
          '"$_resolvedExecutable".',
        ),
      );
    }

    final scriptPath = _resolveDevScriptPath();
    return Success(
      HiveMcpLaunchCommand(
        executable: _resolvedExecutable,
        baseArguments: <String>['run', scriptPath],
      ),
    );
  }

  String _resolveDevScriptPath() {
    if (_scriptPathOverride != null) {
      return _scriptPathOverride;
    }

    final candidates = <String>[
      _path.join(Directory.current.path, 'bin', 'hive_mcp.dart'),
      _path.join(Directory.current.path, 'backend', 'bin', 'hive_mcp.dart'),
      if (Platform.script.isScheme('file') &&
          Platform.script.path.endsWith('.dart'))
        _path.join(
          _path.dirname(_path.dirname(Platform.script.toFilePath())),
          'bin',
          'hive_mcp.dart',
        ),
    ];

    for (final candidate in candidates) {
      final normalized = _path.normalize(candidate);
      if (_fileExists(normalized)) {
        return normalized;
      }
    }

    return _path.normalize(candidates.first);
  }
}
