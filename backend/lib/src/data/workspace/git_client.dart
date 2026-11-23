import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';

/// Thin adapter for executing `git` CLI commands through an injected
/// [ProcessRunner].
final class GitClient {
  /// Creates a git CLI client.
  const new(this._processRunner);

  /// Default timeout for git CLI invocations.
  static const defaultTimeout = Duration(seconds: 30);

  /// Timeout for commands that scan or rewrite a whole workspace (`add`,
  /// `commit`, `reset`, `clean`, `ls-files`, ...), which can legitimately take
  /// minutes on large folders.
  static const longTimeout = Duration(minutes: 5);

  final ProcessRunner _processRunner;

  /// Runs `git` with [arguments] and returns the raw [ProcessRunResult].
  Future<ProcessRunResult> run(
    List<String> arguments, {
    Duration timeout = defaultTimeout,
  }) => _processRunner.run('git', arguments, timeout: timeout);

  /// Runs `git` with [arguments], returning `stdout` on exit code `0` or a
  /// descriptive [Failure] otherwise.
  Future<Result<String>> runChecked(
    List<String> arguments, {
    Duration timeout = defaultTimeout,
    String? failureContext,
  }) async {
    final result = await runAllowingExitCodes(
      arguments,
      allowedExitCodes: const {0},
      timeout: timeout,
      failureContext: failureContext,
    );
    return result.map((run) => run.stdout);
  }

  /// Runs `git` with [arguments] and succeeds with the raw result when the
  /// process exits with one of [allowedExitCodes] (for example `0` and `1` for
  /// `diff --quiet`). Launch errors, timeouts and any other exit code become a
  /// descriptive [Failure].
  Future<Result<ProcessRunResult>> runAllowingExitCodes(
    List<String> arguments, {
    required Set<int> allowedExitCodes,
    Duration timeout = defaultTimeout,
    String? failureContext,
  }) async {
    final result = await run(arguments, timeout: timeout);
    if (result.launchError != null) {
      return FailureResult(
        ValidationFailure(
          'Git is not available: ${result.launchError}. '
          'Install git and ensure it is on PATH.',
        ),
      );
    }
    if (result.timedOut) {
      return FailureResult(
        UnexpectedFailure(
          '${failureContext ?? 'Git command'} timed out after '
          '${timeout.inSeconds}s.',
        ),
      );
    }
    if (!allowedExitCodes.contains(result.exitCode)) {
      final detail = result.stderr.trim().isNotEmpty
          ? result.stderr.trim()
          : result.stdout.trim();
      return FailureResult(
        UnexpectedFailure(
          '${failureContext ?? 'Git command'} failed '
          '(exit ${result.exitCode}): $detail',
        ),
      );
    }
    return Success(result);
  }
}
