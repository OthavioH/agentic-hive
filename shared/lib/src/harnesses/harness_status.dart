/// Detected availability and readiness state of a CLI harness.
enum HarnessStatus {
  /// Binary found on `PATH`, version parsed, and no auth or update errors.
  ready,

  /// Binary was not found on `PATH`.
  notInstalled,

  /// CLI reported an authentication or sign-in failure.
  authError,

  /// CLI reported that an update is required before running.
  outdated,

  /// Binary was found, but probing failed (timeout, non-zero exit, or
  /// unparseable output).
  unavailable,
}
