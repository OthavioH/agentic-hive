import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// The validated backend configuration.
final class AppConfig {
  /// Creates a configuration; [dataDir] must be absolute.
  const new({
    required this.mode,
    required this.dataDir,
    this._agentsDir,
    this.webSocketPingInterval = defaultPingInterval,
    this.logRetentionDays = defaultLogRetentionDays,
  });

  /// Default interval between WebSocket pings.
  static const defaultPingInterval = Duration(seconds: 20);

  /// Default number of days log files are kept.
  static const defaultLogRetentionDays = 14;

  /// Whether the backend runs from source or as a compiled executable.
  final RuntimeMode mode;

  /// Absolute path of the data folder.
  final String dataDir;

  final String? _agentsDir;

  /// How often the server pings WebSocket clients to detect dead connections.
  final Duration webSocketPingInterval;

  /// How many days of log files are kept, today included.
  final int logRetentionDays;

  /// Fixed by [mode], never configurable: `FINE` in development, `INFO` in
  /// production.
  Level get logLevel =>
      mode == RuntimeMode.production ? Level.INFO : Level.FINE;

  /// The Unix socket the backend listens on.
  String get socketPath => p.join(dataDir, 'backend.sock');

  /// The SQLite database file.
  String get databasePath => p.join(dataDir, 'hive.db');

  /// The folder of the JSON-lines log files.
  String get logsDir => p.join(dataDir, 'logs');

  /// The `server.json` file read by the frontend.
  String get serverInfoPath => p.join(dataDir, 'server.json');

  /// The folder where agent `.md` files are stored.
  String get agentsDir => _agentsDir ?? p.join(dataDir, 'agents');

  /// The folder where per-run shadow git repositories are stored.
  String get snapshotsDir => p.join(dataDir, 'snapshots');

  /// The folder where per-run isolated git worktrees are stored.
  String get worktreesDir => p.join(dataDir, 'worktrees');

  /// The folder where per-run artifacts (such as node attempt logs) are
  /// stored.
  String get runsDir => p.join(dataDir, 'runs');

  /// The folder for a single run's backend-managed files.
  String runDir(String runId) => p.join(runsDir, runId);

  /// The folder where raw `stdout`/`stderr` attempt logs for [runId] live.
  String runLogsDir(String runId) => p.join(runsDir, runId, 'logs');
}
