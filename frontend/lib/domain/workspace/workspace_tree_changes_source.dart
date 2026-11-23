/// What changed in the data behind the side rail tree.
enum WorkspaceTreeChange {
  /// A run started, paused, resumed, finished or was cancelled.
  run,

  /// A pause was created or resolved.
  pause,

  /// A workspace was registered, renamed or unregistered.
  workspace,

  /// A worktree was created or removed.
  worktree,

  /// The live connection came back, so anything may have changed meanwhile.
  resync,
}

/// Live feed of changes that affect the side rail tree.
abstract interface class WorkspaceTreeChangesSource {
  /// Emits a [WorkspaceTreeChange] each time the backend reports a run,
  /// pause, workspace or worktree change, and after a reconnect.
  Stream<WorkspaceTreeChange> get changes;
}
