import 'dart:convert';

import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/logging/redactor.dart';
import 'package:logging/logging.dart';

/// Turns a [LogRecord] into a console line or a JSON object, applying the
/// redaction and user-content rules.
final class LogFormatter {
  /// Creates a formatter that redacts through [_redactor].
  new(this._redactor);

  /// User content longer than this is truncated.
  static const maxUserContentLength = 500;

  final Redactor _redactor;

  /// The JSON shape written to `logs/*.jsonl`.
  Map<String, Object?> toJson(LogRecord record) {
    final event = record.object is LogEvent ? record.object! as LogEvent : null;
    final userContent = _userContent(record, event);
    return {
      'time': record.time.toUtc().toIso8601String(),
      'level': record.level.name,
      'logger': _redactor.redactText(record.loggerName),
      'message': _redactor.redactText(event?.name ?? record.message),
      if (event != null && event.fields.isNotEmpty)
        'fields': _redactor.redactFields(event.fields),
      'userContent': ?userContent,
      if (record.error != null)
        'error': _redactor.redactText(record.error.toString()),
      if (record.stackTrace != null)
        'stackTrace': _redactor.redactText(record.stackTrace.toString()),
    };
  }

  /// [toJson] encoded as one line.
  String toJsonLine(LogRecord record) => jsonEncode(toJson(record));

  /// A readable single line (plus error and stack trace lines) for the
  /// console.
  String toConsoleLine(LogRecord record) {
    final json = toJson(record);
    final buffer = StringBuffer()
      ..write(json['time'])
      ..write(' ')
      ..write(record.level.name.padRight(7))
      ..write(' ')
      ..write(record.loggerName)
      ..write(': ')
      ..write(json['message']);
    final fields = json['fields'];
    if (fields is Map<String, Object?>) {
      for (final entry in fields.entries) {
        buffer.write(' ${entry.key}=${entry.value}');
      }
    }
    if (json['userContent'] case final String content) {
      buffer.write('\n  content: $content');
    }
    if (json['error'] case final Object error) {
      buffer.write('\n  error: $error');
    }
    if (json['stackTrace'] case final Object stackTrace) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }

  String? _userContent(LogRecord record, LogEvent? event) {
    final content = event?.userContent;
    if (content == null || record.level >= Level.INFO) return null;
    final redacted = _redactor.redactText(content);
    return redacted.length <= maxUserContentLength
        ? redacted
        : '${redacted.substring(0, maxUserContentLength)}…';
  }
}
