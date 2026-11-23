/// Where an agent `.md` file lives (ADR 0022).
enum AgentScope {
  /// `~/.agents/agents`, shared by every workspace.
  global,

  /// `<workspace root>/.agents/agents`, overriding a global agent with the
  /// same `name`.
  workspace;

  /// Parses an [AgentScope] by its enum [name], throwing a [FormatException]
  /// when unknown.
  static AgentScope fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown AgentScope "$name".');
  }
}
