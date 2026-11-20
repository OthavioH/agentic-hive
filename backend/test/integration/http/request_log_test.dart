@Timeout(Duration(seconds: 60))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  test('each request writes an http.request line without the query string '
      'to logs/backend-<today UTC>.jsonl', () async {
    const marker = 'q5ecr3tMarker';
    final dataDir = (await createTempDir()).path;
    final dayBefore = _utcDay(DateTime.now());
    final backend = await startBackend(dataDir, stopOnTearDown: false);
    final client = openClient(backend.socketPath);

    final response = await client.get('/health?token=$marker&x=1');
    final requestId = response.headers.value('x-request-id');
    expect(response.statusCode, 200);
    // Stopping flushes and closes the file sink.
    await backend.stop().timeout(ioTimeout);
    final dayAfter = _utcDay(DateTime.now());

    final lines = [
      for (final day in {dayBefore, dayAfter})
        ..._readLines(p.join(dataDir, 'logs', 'backend-$day.jsonl')),
    ];
    expect(lines, isNotEmpty, reason: 'no log file for $dayBefore');
    for (final line in lines) {
      expect(line, isNot(contains(marker)));
      expect(line, isNot(contains('token=')));
    }

    final requests = lines
        .map((line) => jsonDecode(line) as JsonMap)
        .where((entry) => entry['message'] == 'http.request')
        .map((entry) => entry['fields']! as JsonMap)
        .where((fields) => fields['requestId'] == requestId)
        .toList();
    expect(requests, hasLength(1));
    final fields = requests.single;
    expect(fields['method'], 'GET');
    expect(fields['path'], '/health');
    expect(fields['status'], 200);
    expect(fields['durationMs'], isA<int>());
  });
}

String _utcDay(DateTime time) {
  final utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
}

List<String> _readLines(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  return file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .toList();
}
