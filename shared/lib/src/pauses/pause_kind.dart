/// Kind of human pause requested by a workflow run.
enum PauseKind {
  /// A `human_approval` node waiting for an approve/reject decision.
  humanApproval,

  /// A harness that called `ask_human` and is waiting for a free-form answer.
  askHuman;

  /// Parses a [PauseKind] by its enum [name], throwing a [FormatException]
  /// when unknown.
  static PauseKind fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown PauseKind "$name".');
  }
}
