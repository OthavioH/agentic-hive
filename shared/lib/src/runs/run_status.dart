/// Lifecycle status of a workflow run.
enum RunStatus {
  /// The run exists and its new worktree is being created in the background
  /// (preparation); no node runs yet.
  preparing,

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

  /// Whether this run is still active (`preparing`, `running`, `paused`, or
  /// `cancelling`).
  bool get isActive =>
      this == preparing ||
      this == running ||
      this == paused ||
      this == cancelling;

  /// Whether this run is `preparing`, `running`, or `paused`.
  ///
  /// Overview lists `preparing`, `running`, and `paused` as active and
  /// partitions them from recent runs (all other statuses, including
  /// `cancelling`).
  bool get isRunningOrPaused =>
      this == preparing || this == running || this == paused;

  /// Whether processes of this run may still be executing and writing to the
  /// workspace (`preparing`, `running`, or `cancelling`).
  ///
  /// While `preparing`, git writes into the workspace, so workspace snapshot
  /// restoration stays blocked while [isExecutingProcesses] is `true` and is
  /// allowed in all other states (including `paused` and `interrupted`).
  bool get isExecutingProcesses =>
      this == preparing || this == running || this == cancelling;

  /// Parses a [RunStatus] by its enum [name], throwing a [FormatException]
  /// when unknown.
  static RunStatus fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown RunStatus "$name".');
  }
}
