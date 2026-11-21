/// Lifecycle status of a workflow run.
enum RunStatus {
  /// The run is actively executing nodes.
  running,

  /// The run is waiting for human input (approval node or `ask_human`).
  paused,

  /// Cancellation was requested and the backend is terminating active
  /// process trees.
  cancelling,

  /// Cancellation was requested, but process tree exit could not be
  /// confirmed within the timeout.
  cancellationUncertain,

  /// The run was interrupted by a backend restart while running.
  interrupted,

  /// The run finished all reachable work without failure.
  succeeded,

  /// The run terminated due to a node or infrastructure failure.
  failed,

  /// The run was cancelled by the user.
  cancelled;

  /// Whether this run is still active (`running`, `paused`, or `cancelling`).
  bool get isActive => this == running || this == paused || this == cancelling;

  /// Parses a [RunStatus] by its enum [name], throwing a [FormatException]
  /// when unknown.
  static RunStatus fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown RunStatus "$name".');
  }
}
