/// Lifecycle status of a workflow run.
enum RunStatus {
  /// The run is actively executing nodes.
  running,

  /// The run is waiting for human input (approval node or `ask_human`).
  paused,

  /// The run was interrupted by a backend restart while running.
  interrupted,

  /// The run finished all reachable work without failure.
  succeeded,

  /// The run terminated due to a node or infrastructure failure.
  failed,

  /// The run was cancelled by the user.
  cancelled;

  /// Whether this run is still active (`running` or `paused`).
  bool get isActive => this == running || this == paused;

  /// Parses a [RunStatus] by its enum [name], throwing a [FormatException]
  /// when unknown.
  static RunStatus fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown RunStatus "$name".');
  }
}
