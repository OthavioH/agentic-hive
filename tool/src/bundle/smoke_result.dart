/// Outcome of one smoke test.
sealed class SmokeResult {
  /// Creates a [SmokeResult].
  const new();

  /// Process exit code: 0 for [SmokePassed], 1 for every [SmokeFailure].
  int get exitCode;

  /// Human-readable summary of the outcome.
  String get message;
}

/// The smoke test passed all checks.
final class SmokePassed extends SmokeResult {
  /// Creates a [SmokePassed] with total [elapsed] duration.
  const new(this.elapsed);

  /// Total time taken by the smoke test.
  final Duration elapsed;

  @override
  int get exitCode => 0;

  @override
  String get message {
    final secs = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    return 'PASSED: the bundled backend started, answered GET /health and '
        'stopped, and hive_mcp answered MCP initialize (${secs}s).';
  }
}

/// Base class for all smoke test failures.
sealed class SmokeFailure extends SmokeResult {
  /// Creates a [SmokeFailure].
  const new();

  /// Name of the step that failed.
  String get step;

  /// Detailed explanation of the failure.
  String get detail;

  @override
  int get exitCode => 1;

  @override
  String get message => 'FAILED at $step: $detail';
}

/// One or more required files were missing from the bundle.
final class MissingFilesFailure extends SmokeFailure {
  /// Creates a [MissingFilesFailure] for [paths].
  const new(this.paths);

  /// Missing file paths in check order.
  final List<String> paths;

  @override
  String get step => 'layout';

  @override
  String get detail {
    final lines = paths.map((path) => '  - $path').join('\n');
    return 'missing file(s):\n$lines';
  }
}

/// The backend server process could not be started.
final class ServerLaunchFailure extends SmokeFailure {
  /// Creates a [ServerLaunchFailure].
  const new(this.serverPath, this.error);

  /// Path to the server executable.
  final String serverPath;

  /// OS error message.
  final String error;

  @override
  String get step => 'start';

  @override
  String get detail => 'could not start $serverPath: $error';
}

/// The backend server exited before writing `server.json`.
final class ServerExitedFailure extends SmokeFailure {
  /// Creates a [ServerExitedFailure].
  const new(this.serverExitCode, this.output);

  /// Exit code returned by the server process.
  final int serverExitCode;

  /// Captured server output.
  final String output;

  @override
  String get step => 'start';

  @override
  String get detail {
    final out = output.isEmpty ? '(no output)' : output;
    return 'the server exited with code $serverExitCode before writing '
        'server.json.\nServer output:\n$out';
  }
}

/// `server.json` did not appear within [timeout].
final class ServerInfoTimeoutFailure extends SmokeFailure {
  /// Creates a [ServerInfoTimeoutFailure].
  const new(this.serverInfoPath, this.timeout, this.output);

  /// Expected path of `server.json`.
  final String serverInfoPath;

  /// Configured startup timeout.
  final Duration timeout;

  /// Captured server output.
  final String output;

  @override
  String get step => 'start';

  @override
  String get detail {
    final out = output.isEmpty ? '(no output)' : output;
    return '$serverInfoPath did not appear within ${timeout.inSeconds}s.\n'
        'Server output:\n$out';
  }
}

/// `server.json` could not be parsed or was missing required fields.
final class InvalidServerInfoFailure extends SmokeFailure {
  /// Creates an [InvalidServerInfoFailure].
  const new(this.serverInfoPath, this.reason);

  /// Path to the invalid `server.json`.
  final String serverInfoPath;

  /// Validation or parse error message.
  final String reason;

  @override
  String get step => 'server.json';

  @override
  String get detail => '$serverInfoPath is invalid: $reason';
}

/// `GET /health` failed or returned a non-200 status code.
final class HealthCheckFailure extends SmokeFailure {
  /// Creates a [HealthCheckFailure].
  const new(this.statusCode, this.detailText);

  /// HTTP status code if a response was received, otherwise `null`.
  final int? statusCode;

  /// Response body or error description.
  final String detailText;

  @override
  String get step => 'health';

  @override
  String get detail => statusCode != null
      ? 'GET /health answered $statusCode: $detailText'
      : 'GET /health failed: $detailText';
}

/// The server did not stop cleanly after `POST /api/v1/shutdown`.
final class StopFailure extends SmokeFailure {
  /// Creates a [StopFailure].
  const new(this.reason);

  /// Description of the stop failure.
  final String reason;

  @override
  String get step => 'stop';

  @override
  String get detail => 'the server did not stop cleanly: $reason';
}

/// `backend/bin/hive_mcp` did not answer an MCP `initialize` request.
final class McpProxyFailure extends SmokeFailure {
  /// Creates a [McpProxyFailure].
  const new(this.reason, this.output);

  /// What went wrong.
  final String reason;

  /// Captured hive_mcp stdout and stderr.
  final String output;

  @override
  String get step => 'mcp';

  @override
  String get detail {
    final out = output.isEmpty ? '(no output)' : output;
    return 'hive_mcp did not answer MCP initialize: $reason.\n'
        'hive_mcp output:\n$out';
  }
}
