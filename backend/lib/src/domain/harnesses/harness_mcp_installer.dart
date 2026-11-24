import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Canonical MCP server name registered in each harness CLI.
const hiveMcpServerName = 'hive';

/// Environment variables forwarded from the harness process to `hive-mcp`.
const hiveMcpEnvVarNames = <String>[
  'HIVE_SOCKET_PATH',
  'HIVE_RUN_ID',
  'HIVE_NODE_ID',
  'HIVE_ATTEMPT',
];

/// Default timeout for probing a harness's MCP configuration.
const defaultMcpProbeTimeout = Duration(seconds: 6);

/// Default timeout for installing the `hive` MCP server via a harness CLI.
const defaultMcpInstallTimeout = Duration(seconds: 15);

/// Outcome of probing whether `hive-mcp` is installed in a harness CLI.
final class HarnessMcpDetectionResult {
  /// Creates a detection result.
  const new({required this.status, this.message});

  /// Detected installation status.
  final HarnessMcpStatus status;

  /// Optional human-readable explanation (for example why it is outdated or
  /// unknown).
  final String? message;
}

/// Detects and installs the `hive` MCP server in a single CLI harness.
abstract interface class HarnessMcpInstaller {
  /// The harness identifier this installer handles.
  HarnessId get id;

  /// User-level configuration file path written by this installer, or `null`
  /// when the CLI manages storage opaquely.
  String? get configPath;

  /// Probes the harness's user-level MCP configuration.
  Future<HarnessMcpDetectionResult> detect({
    required String executablePath,
    required HiveMcpLaunchCommand expectedCommand,
  });

  /// Installs or updates the `hive` MCP server in the harness's user-level
  /// configuration.
  Future<Result<void>> install({
    required String executablePath,
    required HiveMcpLaunchCommand command,
  });
}

/// Registry of [HarnessMcpInstaller]s keyed by [HarnessId].
final class HarnessMcpInstallerRegistry {
  /// Creates a registry from [installers].
  new(Iterable<HarnessMcpInstaller> installers)
    : _byId = {for (final installer in installers) installer.id: installer};

  final Map<HarnessId, HarnessMcpInstaller> _byId;

  /// Returns the installer for [id], or `null` if unsupported.
  HarnessMcpInstaller? operator [](HarnessId id) => _byId[id];
}
