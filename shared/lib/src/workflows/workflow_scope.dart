/// Where a workflow definition lives (ADR 0025).
enum WorkflowScope {
  /// Stored in SQLite and shared by every workspace.
  global,

  /// Stored as `<workspace root>/.agentic-hive/workflows/<slug>.json`.
  workspace;

  /// Parses a [WorkflowScope] by its enum [name], throwing a
  /// [FormatException] when unknown.
  static WorkflowScope fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown WorkflowScope "$name".');
  }
}
