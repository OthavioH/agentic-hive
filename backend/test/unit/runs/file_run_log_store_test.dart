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
    'appends per-attempt logs with monotonic offsets, streams outputs, tails '
    'from end, and deletes',
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
      expect(streamed[0].offset, 1);
      expect(streamed[1].offset, 1);
      expect(streamed[2].offset, 2);
      expect(streamed[2].stream, RunOutputStream.stderr);
      expect(streamed[3].offset, 3);

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
      expect(latest.entries.map((e) => e.offset), [1, 2, 3]);
      expect(latest.offset, 3);
      expect(latest.truncated, isFalse);

      // Specific attempt (1).
      final first = (await store.readLogs(
        runId: 'run-1',
        nodeId: 'node/a',
        attempt: 1,
      )).valueOrNull!;
      expect(first.attempt, 1);
      expect(first.entries.single.chunk, 'attempt 1 out');
      expect(first.entries.single.offset, 1);
      expect(first.offset, 1);

      // Tail lines reads from end and sets truncated + latest offset.
      final tailed = (await store.readLogs(
        runId: 'run-1',
        nodeId: 'node/a',
        tailLines: 2,
      )).valueOrNull!;
      expect(tailed.truncated, isTrue);
      expect(tailed.entries.map((e) => e.chunk), ['line 2', 'line 3']);
      expect(tailed.entries.map((e) => e.offset), [2, 3]);
      expect(tailed.offset, 3);

      // Delete closes open sinks and removes <runsDir>/<runId>.
      await store.deleteRunLogs('run-1');
      expect(Directory(p.join(tempDir.path, 'run-1')).existsSync(), isFalse);
    },
  );

  test('enforces per-file size cap with truncation marker and keeps offsets '
      'monotonic', () async {
    final cappedStore = FileRunLogStore(
      runsDir: tempDir.path,
      maxLogFileBytes: 180,
    );
    addTearDown(cappedStore.close);

    final streamed = <RunOutputPayload>[];
    final sub = cappedStore.outputs.listen(streamed.add);
    addTearDown(sub.cancel);

    final t0 = DateTime.utc(2026, 11, 20, 12);
    for (var i = 1; i <= 4; i++) {
      await cappedStore.appendOutput(
        runId: 'run-cap',
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'line-$i-payload-content',
        timestamp: t0.add(Duration(seconds: i)),
      );
    }

    expect(streamed.map((e) => e.offset), [1, 2, 3, 4]);
    final logs = (await cappedStore.readLogs(
      runId: 'run-cap',
      nodeId: 'n1',
    )).valueOrNull!;
    expect(logs.truncated, isTrue);
    expect(
      logs.entries.any((e) => e.chunk == FileRunLogStore.truncationMarkerChunk),
      isTrue,
    );
  });
}
