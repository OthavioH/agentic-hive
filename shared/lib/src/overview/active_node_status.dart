/// Execution status of an active node in an active run.
enum ActiveNodeStatus {
  /// The node is currently executing.
  running,

  /// The node is waiting for human input (approval or `ask_human`).
  paused;

  /// Parses an [ActiveNodeStatus] by its enum [name], throwing a
  /// [FormatException] when unknown.
  static ActiveNodeStatus fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown ActiveNodeStatus "$name".');
  }
}
