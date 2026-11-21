import 'dart:io';

import 'package:agentic_hive_backend/src/data/runs/file_run_log_store.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late FileRunLogStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_log_store_');
    store = FileRunLogStore(runsDir: tempDir.path);
  });

  tearDown(() async {
    await store.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'appends per-attempt logs, streams outputs, tails, and deletes',
    () async {
      final streamed = <RunOutputPayload>[];
      final sub = store.outputs.listen(streamed.add);
      addTearDown(sub.cancel);

      final t0 = DateTime.utc(2026, 11, 20, 12);
      await store.appendOutput(
        runId: 'run-1',
        nodeId: 'node/a',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'attempt 1 out',
        timestamp: t0,
      );
      await store.appendOutput(
        runId: 'run-1',
        nodeId: 'node/a',
        attempt: 2,
        stream: RunOutputStream.stdout,
        chunk: 'line 1',
        timestamp: t0.add(const Duration(seconds: 1)),
      );
      await store.appendOutput(
        runId: 'run-1',
        nodeId: 'node/a',
        attempt: 2,
        stream: RunOutputStream.stderr,
        chunk: 'line 2',
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      await store.appendOutput(
        runId: 'run-1',
        nodeId: 'node/a',
        attempt: 2,
        stream: RunOutputStream.stdout,
        chunk: 'line 3',
        timestamp: t0.add(const Duration(seconds: 3)),
      );

      expect(streamed, hasLength(4));
      expect(streamed[2].stream, RunOutputStream.stderr);

      // Defaults to latest attempt (2).
      final latest = (await store.readLogs(
        runId: 'run-1',
        nodeId: 'node/a',
      )).valueOrNull!;
      expect(latest.attempt, 2);
      expect(latest.availableAttempts, [1, 2]);
      expect(latest.entries.map((e) => e.chunk), [
        'line 1',
        'line 2',
        'line 3',
      ]);
      expect(latest.truncated, isFalse);

      // Specific attempt (1).
      final first = (await store.readLogs(
        runId: 'run-1',
        nodeId: 'node/a',
        attempt: 1,
      )).valueOrNull!;
      expect(first.attempt, 1);
      expect(first.entries.single.chunk, 'attempt 1 out');

      // Tail lines sets truncated.
      final tailed = (await store.readLogs(
        runId: 'run-1',
        nodeId: 'node/a',
        tailLines: 2,
      )).valueOrNull!;
      expect(tailed.truncated, isTrue);
      expect(tailed.entries.map((e) => e.chunk), ['line 2', 'line 3']);

      // Delete removes <runsDir>/<runId>.
      await store.deleteRunLogs('run-1');
      expect(Directory(p.join(tempDir.path, 'run-1')).existsSync(), isFalse);
    },
  );
}
