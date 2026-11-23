/// Standard output stream identifier for node execution logs.
enum RunOutputStream {
  /// Standard output (`stdout`).
  stdout,

  /// Standard error (`stderr`).
  stderr;

  /// Parses a [RunOutputStream] by its enum [name], throwing a
  /// [FormatException] when unknown.
  static RunOutputStream fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown RunOutputStream "$name".');
  }
}
