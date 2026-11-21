/// Result of executing a short-lived subprocess with closed `stdin`.
final class ProcessRunResult {
  /// Creates a process run result.
  const new({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
    this.launchError,
  });

  /// Exit code of the process, or `-1` when it timed out or failed to launch.
  final int exitCode;

  /// Decoded standard output.
  final String stdout;

  /// Decoded standard error.
  final String stderr;

  /// Whether the subprocess exceeded the configured timeout and was killed.
  final bool timedOut;

  /// Non-null when the operating system failed to start the executable.
  final String? launchError;
}

/// Runs a short-lived subprocess with `stdin` closed immediately.
abstract interface class ProcessRunner {
  /// Executes [executable] with [arguments] and kills it after [timeout].
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  });
}
