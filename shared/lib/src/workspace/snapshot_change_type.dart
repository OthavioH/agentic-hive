/// Kind of change for a file in a snapshot diff.
enum SnapshotChangeType {
  /// File was added in this snapshot.
  added,

  /// File was modified in this snapshot.
  modified,

  /// File was deleted in this snapshot.
  deleted;

  /// Parses a [SnapshotChangeType] by its enum [name], throwing a
  /// [FormatException] when unknown.
  static SnapshotChangeType fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown SnapshotChangeType "$name".');
  }
}
