import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/runs/file_run_log_store.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_transcript_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../engine/support/in_memory_repositories.dart';

final class _DeltaFakeNode extends Node {
  const new({required this.typeId});

  @override
  final String typeId;

  @override
  TranscriptInterpreter createTranscriptInterpreter() => _DeltaInterpreter();

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async =>
      const Success(NodeOutcome(outputLabel: 'onSuccess'));
}

final class _PlainFakeNode extends Node {
  const new({required this.typeId});

  @override
  final String typeId;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async =>
      const Success(NodeOutcome(outputLabel: 'onSuccess'));
}

final class _ThrowingFakeNode extends Node {
  const new({required this.typeId});

  @override
  final String typeId;

  @override
  TranscriptInterpreter createTranscriptInterpreter() => _ThrowingInterpreter();

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async =>
      const Success(NodeOutcome(outputLabel: 'onSuccess'));
}

final class _ThrowingInterpreter implements TranscriptInterpreter {
  @override
  List<TranscriptEntry> interpret(RunLogEntry entry) =>
      throw StateError('interpreter crashed');
}

final class _FailingReadLogStore implements RunLogStore {
  new(this._inner);

  final RunLogStore _inner;
  bool failRead = false;

  @override
  Stream<RunOutputPayload> get outputs => _inner.outputs;

  @override
  Future<void> appendOutput({
    required String runId,
    required String nodeId,
    required int attempt,
    required RunOutputStream stream,
    required String chunk,
    required DateTime timestamp,
  }) => _inner.appendOutput(
    runId: runId,
    nodeId: nodeId,
    attempt: attempt,
    stream: stream,
    chunk: chunk,
    timestamp: timestamp,
  );

  @override
  Future<Result<RunNodeLogsResponse>> readLogs({
    required String runId,
    required String nodeId,
    int? attempt,
    int? tailLines,
  }) {
    if (failRead) {
      return Future.value(
        const FailureResult(PersistenceFailure('read failed')),
      );
    }
    return _inner.readLogs(
      runId: runId,
      nodeId: nodeId,
      attempt: attempt,
      tailLines: tailLines,
    );
  }

  @override
  Future<void> deleteRunLogs(String runId) => _inner.deleteRunLogs(runId);

  @override
  Future<void> close() => _inner.close();
}

final class _DeltaInterpreter implements TranscriptInterpreter {
  String? _id;
  int? _firstOffset;
  final _buf = StringBuffer();

  @override
  List<TranscriptEntry> interpret(RunLogEntry entry) {
    if (entry.stream == RunOutputStream.stdout &&
        entry.chunk.startsWith('delta:')) {
      _id ??= transcriptEntryId(entry);
      _firstOffset ??= entry.offset;
      _buf.write(entry.chunk.substring('delta:'.length));
      return [
        TranscriptEntry.agentMessage(
          id: _id!,
          firstOffset: _firstOffset!,
          lastOffset: entry.offset,
          text: _buf.toString(),
        ),
      ];
    }
    return [plainTextEntry(entry)];
  }
}

NodeDescriptor _descriptor(String typeId) => NodeDescriptor(
  typeId: typeId,
  category: NodeCategory.harnesses,
  availableOutputs: const ['onSuccess'],
  defaultConfig: () => const <String, Object?>{},
  validateConfig: (_) => const [],
  configFields: const [],
);

Run _run(String id, {String nodeType = 'fake.delta'}) => Run(
  id: id,
  workflowId: 'wf-1',
  workflowName: 'Test',
  workspaceId: 'ws-1',
  workspaceRoot: '/tmp/ws',
  status: RunStatus.running,
  startedAt: DateTime.utc(2026, 11, 20, 12),
  workflowDefinition: Workflow(
    id: 'wf-1',
    name: 'Test',
    entryNodeId: 'n1',
    nodes: [
      WorkflowNode(
        id: 'n1',
        type: nodeType,
        label: 'Node 1',
        position: const WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    createdAt: DateTime.utc(2026, 11, 20, 12),
    updatedAt: DateTime.utc(2026, 11, 20, 12),
  ),
);

List<TranscriptEntry> _foldPayloads(
  Iterable<RunOutputPayload> payloads, [
  Iterable<TranscriptEntry> initial = const [],
]) {
  final byId = <String, TranscriptEntry>{
    for (final entry in initial) entry.id: entry,
  };
  for (final payload in payloads) {
    for (final entry in payload.transcript) {
      byId[entry.id] = entry;
    }
  }
  return byId.values.toList(growable: false);
}

void main() {
  late Directory tempDir;
  late FileRunLogStore logStore;
  late InMemoryRunRepository runsRepo;
  late InMemoryRunEventRepository eventsRepo;
  late NodeRegistry registry;
  late RunTranscriptService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('run_transcript_test_');
    logStore = FileRunLogStore(runsDir: tempDir.path);
    runsRepo = InMemoryRunRepository();
    eventsRepo = InMemoryRunEventRepository();
    registry = NodeRegistry()
      ..register(
        _descriptor('fake.delta'),
        () => const _DeltaFakeNode(typeId: 'fake.delta'),
      )
      ..register(
        _descriptor('fake.plain'),
        () => const _PlainFakeNode(typeId: 'fake.plain'),
      )
      ..register(
        _descriptor('fake.throwing'),
        () => const _ThrowingFakeNode(typeId: 'fake.throwing'),
      );
    service = RunTranscriptService(
      runs: runsRepo,
      events: eventsRepo,
      logStore: logStore,
      nodes: registry,
    );
  });

  tearDown(() async {
    await service.close();
    await logStore.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('(a) live outputs folded by id equal full REST transcript', () async {
    final run = _run('run-a');
    await runsRepo.create(run);

    final live = <RunOutputPayload>[];
    final sub = service.outputs.listen(live.add);
    addTearDown(sub.cancel);

    final t0 = DateTime.utc(2026, 11, 20, 12);
    await logStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
      stream: RunOutputStream.stdout,
      chunk: 'delta:Hello ',
      timestamp: t0,
    );
    await logStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
      stream: RunOutputStream.stderr,
      chunk: 'stderr line',
      timestamp: t0.add(const Duration(seconds: 1)),
    );
    await logStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
      stream: RunOutputStream.stdout,
      chunk: 'delta:world',
      timestamp: t0.add(const Duration(seconds: 2)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final raw = (await logStore.readLogs(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
    )).valueOrNull!;
    final enriched = (await service.withTranscript(
      run,
      raw,
      tailed: false,
    )).valueOrNull!;

    expect(live, hasLength(3));
    expect(_foldPayloads(live), enriched.transcript);
    expect(enriched.transcript, [
      const TranscriptEntry.agentMessage(
        id: '1',
        firstOffset: 1,
        lastOffset: 3,
        text: 'Hello world',
      ),
      const TranscriptEntry.plainText(
        id: '2',
        firstOffset: 2,
        lastOffset: 2,
        stream: RunOutputStream.stderr,
        text: 'stderr line',
      ),
    ]);
  });

  test(
    '(b) mid-run REST read + subsequent live frames equal full read',
    () async {
      final run = _run('run-b');
      await runsRepo.create(run);

      final live = <RunOutputPayload>[];
      final sub = service.outputs.listen(live.add);
      addTearDown(sub.cancel);

      final t0 = DateTime.utc(2026, 11, 20, 12);
      await logStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:part1-',
        timestamp: t0,
      );
      await logStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'note',
        timestamp: t0.add(const Duration(seconds: 1)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final midRaw = (await logStore.readLogs(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
      )).valueOrNull!;
      final midRes = (await service.withTranscript(
        run,
        midRaw,
        tailed: false,
      )).valueOrNull!;

      await logStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:part2',
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final tailLive = live.where((p) => p.offset > midRes.offset);
      final merged = _foldPayloads(tailLive, midRes.transcript);

      final fullRaw = (await logStore.readLogs(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
      )).valueOrNull!;
      final fullRes = (await service.withTranscript(
        run,
        fullRaw,
        tailed: false,
      )).valueOrNull!;

      expect(merged, fullRes.transcript);
    },
  );

  test(
    '(c) tailed read keeps original id for delta started before tail',
    () async {
      final run = _run('run-c');
      await runsRepo.create(run);

      final t0 = DateTime.utc(2026, 11, 20, 12);
      for (final chunk in ['delta:one ', 'plain', 'delta:two']) {
        await logStore.appendOutput(
          runId: run.id,
          nodeId: 'n1',
          attempt: 1,
          stream: RunOutputStream.stdout,
          chunk: chunk,
          timestamp: t0,
        );
      }

      final fullRaw = (await logStore.readLogs(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
      )).valueOrNull!;
      final fullRes = (await service.withTranscript(
        run,
        fullRaw,
        tailed: false,
      )).valueOrNull!;

      final tailedRaw = (await logStore.readLogs(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        tailLines: 1,
      )).valueOrNull!;
      final tailedRes = (await service.withTranscript(
        run,
        tailedRaw,
        tailed: true,
      )).valueOrNull!;

      // Entry '1' (lastOffset 3) spans into the tail window (offset 3), so it
      // stays with id '1', while entry '2' (lastOffset 2) is excluded.
      expect(tailedRes.transcript, [fullRes.transcript.first]);
      expect(tailedRes.transcript.single.id, '1');
    },
  );

  test(
    '(d) priming a new service replays prior entries for live delta',
    () async {
      final run = _run('run-d');
      await runsRepo.create(run);

      final t0 = DateTime.utc(2026, 11, 20, 12);
      await logStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:before-',
        timestamp: t0,
      );

      final restarted = RunTranscriptService(
        runs: runsRepo,
        events: eventsRepo,
        logStore: logStore,
        nodes: registry,
      );
      addTearDown(restarted.close);

      final live = <RunOutputPayload>[];
      final sub = restarted.outputs.listen(live.add);
      addTearDown(sub.cancel);

      await logStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:after',
        timestamp: t0.add(const Duration(seconds: 1)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final fullRaw = (await logStore.readLogs(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
      )).valueOrNull!;
      final fullRes = (await restarted.withTranscript(
        run,
        fullRaw,
        tailed: false,
      )).valueOrNull!;

      expect(live, hasLength(1));
      expect(live.single.transcript, fullRes.transcript);
      expect(live.single.transcript.single.id, '1');
    },
  );

  test('(e) fallback switches interpreter for the fallback attempt', () async {
    final run = _run('run-e', nodeType: 'fake.plain');
    await runsRepo.create(run);

    final t0 = DateTime.utc(2026, 11, 20, 12);
    await eventsRepo.append(
      id: 'ev-1',
      runId: run.id,
      type: RunEventType.nodeStarted,
      nodeId: 'n1',
      payload: const {'attempt': 1},
      createdAt: t0,
    );
    await eventsRepo.append(
      id: 'ev-2',
      runId: run.id,
      type: RunEventType.nodeFallback,
      nodeId: 'n1',
      payload: const {
        'from': {'harness': 'fake.plain'},
        'to': {'harness': 'fake.delta'},
        'reason': 'rate_limit',
      },
      createdAt: t0.add(const Duration(seconds: 1)),
    );
    await eventsRepo.append(
      id: 'ev-3',
      runId: run.id,
      type: RunEventType.nodeStarted,
      nodeId: 'n1',
      payload: const {'attempt': 2},
      createdAt: t0.add(const Duration(seconds: 2)),
    );

    await logStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
      stream: RunOutputStream.stdout,
      chunk: 'delta:raw',
      timestamp: t0,
    );
    await logStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 2,
      stream: RunOutputStream.stdout,
      chunk: 'delta:interpreted',
      timestamp: t0.add(const Duration(seconds: 3)),
    );

    final raw1 = (await logStore.readLogs(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
    )).valueOrNull!;
    final raw2 = (await logStore.readLogs(
      runId: run.id,
      nodeId: 'n1',
      attempt: 2,
    )).valueOrNull!;

    final res1 = (await service.withTranscript(
      run,
      raw1,
      tailed: false,
    )).valueOrNull!;
    final res2 = (await service.withTranscript(
      run,
      raw2,
      tailed: false,
    )).valueOrNull!;

    expect(res1.transcript.single, isA<TranscriptPlainText>());
    expect(res2.transcript.single, isA<TranscriptAgentMessage>());
  });

  test('(f) truncation marks REST and live marker/post-cap frames', () async {
    final cappedStore = FileRunLogStore(
      runsDir: tempDir.path,
      maxLogFileBytes: 150,
    );
    addTearDown(cappedStore.close);

    final cappedService = RunTranscriptService(
      runs: runsRepo,
      events: eventsRepo,
      logStore: cappedStore,
      nodes: registry,
    );
    addTearDown(cappedService.close);

    final run = _run('run-f');
    await runsRepo.create(run);

    final live = <RunOutputPayload>[];
    final sub = cappedService.outputs.listen(live.add);
    addTearDown(sub.cancel);

    final t0 = DateTime.utc(2026, 11, 20, 12);
    await cappedStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
      stream: RunOutputStream.stdout,
      chunk: 'delta:first',
      timestamp: t0,
    );
    await cappedStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
      stream: RunOutputStream.stdout,
      chunk: 'delta:second-hits-cap',
      timestamp: t0.add(const Duration(seconds: 1)),
    );
    await cappedStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
      stream: RunOutputStream.stdout,
      chunk: 'delta:after-cap',
      timestamp: t0.add(const Duration(seconds: 2)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final raw = (await cappedStore.readLogs(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
    )).valueOrNull!;
    final res = (await cappedService.withTranscript(
      run,
      raw,
      tailed: false,
    )).valueOrNull!;

    expect(res.rawLogTruncated, isTrue);
    expect(live, hasLength(3));
    expect(live[0].rawLogTruncated, isFalse);
    expect(live[1].rawLogTruncated, isTrue);
    expect(live[1].transcript, [
      const TranscriptEntry.plainText(
        id: '2',
        firstOffset: 2,
        lastOffset: 2,
        stream: RunOutputStream.stderr,
        text: '[log truncated: maximum log size reached]',
      ),
    ]);
    expect(live[2].rawLogTruncated, isTrue);
    expect(live[2].transcript, isEmpty);
    expect(_foldPayloads(live), res.transcript);
  });

  test('(g) old run without offsets or node.started events still builds '
      'transcript', () async {
    final run = _run('run-g', nodeType: 'fake.plain');
    await runsRepo.create(run);

    final logsDir = Directory(p.join(tempDir.path, run.id, 'logs'));
    await logsDir.create(recursive: true);
    final logFile = File(p.join(logsDir.path, 'n1__1.jsonl'));
    final line = jsonEncode(<String, Object?>{
      'stream': 'stdout',
      'chunk': 'legacy line',
      'timestamp': '2026-11-20T12:00:00.000Z',
    });
    await logFile.writeAsString('$line\n');

    final raw = (await logStore.readLogs(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
    )).valueOrNull!;
    final res = (await service.withTranscript(
      run,
      raw,
      tailed: false,
    )).valueOrNull!;

    expect(res.transcript, [
      const TranscriptEntry.plainText(
        id: '1',
        firstOffset: 1,
        lastOffset: 1,
        stream: RunOutputStream.stdout,
        text: 'legacy line',
      ),
    ]);
  });

  test(
    'drops cached live state on node.started so resume matches history',
    () async {
      final run = _run('run-resume', nodeType: 'fake.plain');
      await runsRepo.create(run);

      final runEvents = StreamController<RunEvent>.broadcast();
      addTearDown(runEvents.close);

      final resumeService = RunTranscriptService(
        runs: runsRepo,
        events: eventsRepo,
        logStore: logStore,
        nodes: registry,
        runEvents: runEvents.stream,
      );
      addTearDown(resumeService.close);

      final live = <RunOutputPayload>[];
      final sub = resumeService.outputs.listen(live.add);
      addTearDown(sub.cancel);

      final t0 = DateTime.utc(2026, 11, 20, 12);
      Future<void> emitEvent(
        String id,
        RunEventType type,
        DateTime at,
        JsonMap payload,
      ) async {
        final res = await eventsRepo.append(
          id: id,
          runId: run.id,
          type: type,
          nodeId: 'n1',
          payload: payload,
          createdAt: at,
        );
        runEvents.add(res.valueOrNull!);
      }

      await emitEvent('ev-1', RunEventType.nodeStarted, t0, const {
        'attempt': 1,
      });
      await logStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:before-resume',
        timestamp: t0,
      );
      await emitEvent(
        'ev-2',
        RunEventType.nodeFallback,
        t0.add(const Duration(seconds: 1)),
        const {
          'from': {'harness': 'fake.plain'},
          'to': {'harness': 'fake.delta'},
          'reason': 'rate_limit',
        },
      );
      await emitEvent(
        'ev-3',
        RunEventType.nodeStarted,
        t0.add(const Duration(seconds: 2)),
        const {'attempt': 2},
      );
      // Simulate resume restarting attempt numbering at 1 on the fallback
      // harness.
      await emitEvent(
        'ev-4',
        RunEventType.nodeStarted,
        t0.add(const Duration(seconds: 3)),
        const {'attempt': 1},
      );
      await logStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:-after-resume',
        timestamp: t0.add(const Duration(seconds: 4)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final raw = (await logStore.readLogs(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
      )).valueOrNull!;
      final fullRes = (await resumeService.withTranscript(
        run,
        raw,
        tailed: false,
      )).valueOrNull!;

      expect(live, hasLength(2));
      expect(live[0].transcript.single, isA<TranscriptPlainText>());
      expect(live[1].transcript.single, isA<TranscriptAgentMessage>());
      expect(live[1].transcript.single.id, '1');
      expect(_foldPayloads(live), fullRes.transcript);
    },
  );

  test(
    'priming a new service after the cap emits empty post-cap frames',
    () async {
      final cappedStore = FileRunLogStore(
        runsDir: tempDir.path,
        maxLogFileBytes: 150,
      );
      addTearDown(cappedStore.close);

      final run = _run('run-cap-prime');
      await runsRepo.create(run);

      final t0 = DateTime.utc(2026, 11, 20, 12);
      await cappedStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:first',
        timestamp: t0,
      );
      await cappedStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:second-hits-cap',
        timestamp: t0.add(const Duration(seconds: 1)),
      );

      final restarted = RunTranscriptService(
        runs: runsRepo,
        events: eventsRepo,
        logStore: cappedStore,
        nodes: registry,
      );
      addTearDown(restarted.close);

      final live = <RunOutputPayload>[];
      final sub = restarted.outputs.listen(live.add);
      addTearDown(sub.cancel);

      await cappedStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:after-cap',
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(live, hasLength(1));
      expect(live.single.rawLogTruncated, isTrue);
      expect(live.single.transcript, isEmpty);
    },
  );

  test('live error path still emits raw frame unchanged', () async {
    final run = _run('run-live-err', nodeType: 'fake.throwing');
    await runsRepo.create(run);

    final live = <RunOutputPayload>[];
    final sub = service.outputs.listen(live.add);
    addTearDown(sub.cancel);

    await logStore.appendOutput(
      runId: run.id,
      nodeId: 'n1',
      attempt: 1,
      stream: RunOutputStream.stdout,
      chunk: 'raw-line',
      timestamp: DateTime.utc(2026, 11, 20, 12),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(live, hasLength(1));
    expect(live.single.chunk, 'raw-line');
    expect(live.single.transcript, isEmpty);
  });

  test(
    'failed log re-read fails tailed withTranscript and skips prime cache',
    () async {
      final failingStore = _FailingReadLogStore(logStore);
      final failingService = RunTranscriptService(
        runs: runsRepo,
        events: eventsRepo,
        logStore: failingStore,
        nodes: registry,
      );
      addTearDown(failingService.close);

      final run = _run('run-read-fail');
      await runsRepo.create(run);

      final t0 = DateTime.utc(2026, 11, 20, 12);
      await failingStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:one-',
        timestamp: t0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final tailedRaw = (await failingStore.readLogs(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        tailLines: 1,
      )).valueOrNull!;

      // Simulate transient read failure during tailed read and during priming.
      final restarted = RunTranscriptService(
        runs: runsRepo,
        events: eventsRepo,
        logStore: failingStore,
        nodes: registry,
      );
      addTearDown(restarted.close);

      final live = <RunOutputPayload>[];
      final sub = restarted.outputs.listen(live.add);
      addTearDown(sub.cancel);

      failingStore.failRead = true;

      final tailRes = await restarted.withTranscript(
        run,
        tailedRaw,
        tailed: true,
      );
      expect(tailRes, isA<FailureResult<RunNodeLogsResponse>>());

      await failingStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:two-',
        timestamp: t0.add(const Duration(seconds: 1)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Read recovers before the next frame; because the failed prime was not
      // cached, the next frame primes from disk and produces the merged id '1'.
      failingStore.failRead = false;
      await failingStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'three',
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(live, hasLength(2));
      expect(live[1].transcript.single.id, '3');
      // And a fresh delta on the recovered prime merges with offsets 1 and 2.
      await failingStore.appendOutput(
        runId: run.id,
        nodeId: 'n1',
        attempt: 1,
        stream: RunOutputStream.stdout,
        chunk: 'delta:four',
        timestamp: t0.add(const Duration(seconds: 3)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(live, hasLength(3));
      expect(
        live[2].transcript.single,
        const TranscriptEntry.agentMessage(
          id: '1',
          firstOffset: 1,
          lastOffset: 4,
          text: 'one-two-four',
        ),
      );
    },
  );
}
