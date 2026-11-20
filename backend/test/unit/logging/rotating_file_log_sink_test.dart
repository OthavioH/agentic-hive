import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/logging/log_formatter.dart';
import 'package:agentic_hive_backend/src/logging/log_sink.dart';
import 'package:agentic_hive_backend/src/logging/redactor.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

LogRecord _record(String name) {
  final event = LogEvent(name);
  return LogRecord(Level.INFO, name, 'test', null, null, null, event);
}

void main() {
  late Directory tempDir;
  late String logsDir;
  late DateTime now;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('log_sink_test_');
    logsDir = p.join(tempDir.path, 'logs');
    now = DateTime.utc(2026, 11, 20, 10);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  RotatingFileLogSink sinkWith({int retentionDays = 14}) => RotatingFileLogSink(
    LogFormatter(Redactor()),
    directory: logsDir,
    retentionDays: retentionDays,
    now: () => now,
  );

  List<String> messagesIn(String fileName) =>
      File(p.join(logsDir, fileName))
          .readAsLinesSync()
          .map((line) => (jsonDecode(line) as Map<String, Object?>)['message'])
          .cast<String>()
          .toList();

  List<String> fileNames() =>
      Directory(logsDir).listSync().map((e) => p.basename(e.path)).toList()
        ..sort();

  void touch(String fileName) {
    File(p.join(logsDir, fileName))
      ..createSync(recursive: true)
      ..writeAsStringSync('{}\n');
  }

  test('creates the folder and writes backend-YYYY-MM-DD.jsonl', () async {
    final sink = sinkWith()
      ..write(_record('first'))
      ..write(_record('second'));
    await sink.close();

    expect(fileNames(), ['backend-2026-11-20.jsonl']);
    expect(messagesIn('backend-2026-11-20.jsonl'), ['first', 'second']);
  });

  test('names the file after the UTC day', () async {
    now = DateTime.utc(2026, 1, 5, 23, 59, 59);

    final sink = sinkWith()..write(_record('late'));
    await sink.close();

    expect(fileNames(), ['backend-2026-01-05.jsonl']);
  });

  test('appends to an existing file of the same day', () async {
    touch('backend-2026-11-20.jsonl');

    final sink = sinkWith()..write(_record('appended'));
    await sink.close();

    final lines = File(p.join(logsDir, 'backend-2026-11-20.jsonl'))
        .readAsLinesSync();
    expect(lines, hasLength(2));
    expect(lines.first, '{}');
  });

  test('opens a new file when the day changes', () async {
    final sink = sinkWith()..write(_record('day one'));
    now = DateTime.utc(2026, 11, 21, 0, 0, 1);
    sink.write(_record('day two'));
    await sink.close();

    expect(fileNames(), [
      'backend-2026-11-20.jsonl',
      'backend-2026-11-21.jsonl',
    ]);
    expect(messagesIn('backend-2026-11-20.jsonl'), ['day one']);
    expect(messagesIn('backend-2026-11-21.jsonl'), ['day two']);
  });

  test('deletes files older than the retention, keeping today', () async {
    touch('backend-2026-11-17.jsonl');
    touch('backend-2026-11-18.jsonl');
    touch('backend-2026-11-19.jsonl');
    touch('backend-2025-12-31.jsonl');

    final sink = sinkWith(retentionDays: 3)..write(_record('today'));
    await sink.close();

    expect(fileNames(), [
      'backend-2026-11-18.jsonl',
      'backend-2026-11-19.jsonl',
      'backend-2026-11-20.jsonl',
    ]);
  });

  test('keeps only today with a retention of one day', () async {
    touch('backend-2026-11-19.jsonl');

    final sink = sinkWith(retentionDays: 1)..write(_record('today'));
    await sink.close();

    expect(fileNames(), ['backend-2026-11-20.jsonl']);
  });

  test('ignores files and folders that are not its log files', () async {
    touch('other.txt');
    touch('backend-2020-01-01.log');
    touch('backend-2020-01-01.jsonl.bak');
    touch('frontend-2020-01-01.jsonl');
    Directory(p.join(logsDir, 'backend-2020-01-02.jsonl'))
        .createSync(recursive: true);

    final sink = sinkWith(retentionDays: 1)..write(_record('today'));
    await sink.close();

    expect(fileNames(), [
      'backend-2020-01-01.jsonl.bak',
      'backend-2020-01-01.log',
      'backend-2020-01-02.jsonl',
      'backend-2026-11-20.jsonl',
      'frontend-2020-01-01.jsonl',
      'other.txt',
    ]);
  });

  test('deletes expired files again when the day changes', () async {
    final sink = sinkWith(retentionDays: 2)..write(_record('d1'));
    touch('backend-2026-11-19.jsonl');
    now = DateTime.utc(2026, 11, 22);
    sink.write(_record('d3'));
    await sink.close();

    expect(fileNames(), contains('backend-2026-11-22.jsonl'));
    expect(fileNames(), isNot(contains('backend-2026-11-19.jsonl')));
  });

  test('close can be called without any write', () async {
    await sinkWith().close();

    expect(Directory(logsDir).existsSync(), isFalse);
  });
}
