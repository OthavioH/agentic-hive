import 'dart:convert';

/// Keeps the server's console output so a failure can show its last lines.
final class OutputTail {
  /// Creates an [OutputTail] retaining at most [maxLines] non-empty lines.
  new({this.maxLines = 40});

  /// Maximum number of non-empty lines to retain.
  final int maxLines;

  final StringBuffer _buffer = StringBuffer();

  /// Appends [chunk] to the captured output.
  void add(String chunk) {
    _buffer.write(chunk);
  }

  /// Last [maxLines] non-empty lines joined with `\n`.
  String get text {
    final lines = const LineSplitter()
        .convert(_buffer.toString())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= maxLines) {
      return lines.join('\n');
    }
    return lines.sublist(lines.length - maxLines).join('\n');
  }
}
