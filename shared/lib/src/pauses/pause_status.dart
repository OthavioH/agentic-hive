/// Lifecycle status of a pause.
enum PauseStatus {
  /// Waiting for a human response.
  pending,

  /// Answered or decided by a human.
  answered,

  /// Cancelled because the owning run was cancelled or failed.
  cancelled;

  /// Parses a [PauseStatus] by its enum [name], throwing a [FormatException]
  /// when unknown.
  static PauseStatus fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown PauseStatus "$name".');
  }
}
