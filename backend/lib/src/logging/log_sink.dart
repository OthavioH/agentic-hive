import 'dart:io';

import 'package:agentic_hive_backend/src/logging/log_formatter.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// A destination for log records.
abstract interface class LogSink {
  /// Writes [record]; must not throw.
  void write(LogRecord record);

  /// Flushes and releases the destination.
  Future<void> close();
}

/// Writes readable lines to an [IOSink] (stdout by default).
final class ConsoleLogSink implements LogSink {
  /// Creates a sink writing to [out], or stdout.
  new(this._formatter, {IOSink? out}) : _out = out ?? stdout;

  final LogFormatter _formatter;
  final IOSink _out;

  @override
  void write(LogRecord record) =>
      _out.writeln(_formatter.toConsoleLine(record));

  @override
  Future<void> close() => _out.flush();
}

/// Writes JSON lines to `<directory>/backend-YYYY-MM-DD.jsonl`, opening a new
/// file each day (UTC) and deleting files older than [retentionDays].
final class RotatingFileLogSink implements LogSink {
  /// Creates a sink writing under [directory]; [now] is injectable for tests.
  new(
    this._formatter, {
    required this.directory,
    required this.retentionDays,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static final _fileName = RegExp(r'^backend-(\d{4})-(\d{2})-(\d{2})\.jsonl$');

  final LogFormatter _formatter;

  /// Folder of the log files.
  final String directory;

  /// How many days of files are kept, today included.
  final int retentionDays;
  final DateTime Function() _now;

  String? _currentDay;
  IOSink? _sink;

  @override
  void write(LogRecord record) {
    final day = _dayOf(_now());
    if (day != _currentDay) _rotate(day);
    _sink!.writeln(_formatter.toJsonLine(record));
  }

  @override
  Future<void> close() async {
    final sink = _sink;
    _sink = null;
    _currentDay = null;
    await sink?.flush();
    await sink?.close();
  }

  void _rotate(String day) {
    final previous = _sink;
    if (previous != null) {
      previous.close().ignore();
    }
    Directory(directory).createSync(recursive: true);
    _currentDay = day;
    _sink = File(p.join(directory, 'backend-$day.jsonl'))
        .openWrite(mode: FileMode.append);
    _deleteExpired();
  }

  void _deleteExpired() {
    // `_currentDay` is a UTC day; parse it as UTC like the file days below.
    final today = DateTime.parse('${_currentDay!}T00:00:00Z');
    final oldestKept = today.subtract(Duration(days: retentionDays - 1));
    for (final entity in Directory(directory).listSync()) {
      final match = _fileName.firstMatch(p.basename(entity.path));
      if (entity is! File || match == null) continue;
      final fileDay = DateTime.utc(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
      if (fileDay.isBefore(oldestKept)) {
        try {
          entity.deleteSync();
        } on FileSystemException {
          // Another process may hold it open; it will be retried tomorrow.
        }
      }
    }
  }

  static String _dayOf(DateTime time) {
    final utc = time.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}';
  }
}
