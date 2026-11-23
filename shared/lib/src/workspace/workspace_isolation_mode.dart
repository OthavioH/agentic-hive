/// How a workflow run's workspace is isolated from the user's folder.
enum WorkspaceIsolationMode {
  /// The run operates directly on the target workspace folder.
  direct,

  /// The run operates in an isolated git worktree on a `hive/<runId>` branch.
  worktree;

  /// Parses a [WorkspaceIsolationMode] by its enum [name], throwing a
  /// [FormatException] when unknown.
  static WorkspaceIsolationMode fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown WorkspaceIsolationMode "$name".');
  }
}
