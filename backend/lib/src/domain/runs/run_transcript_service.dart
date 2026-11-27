import 'dart:async';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
import 'package:agentic_hive_backend/src/domain/runs/attempt_node_type.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

typedef _AttemptKey = (String runId, String nodeId, int attempt);

final class _LiveAttemptState {
  new({required this.interpreter, this.capped = false});

  final TranscriptInterpreter interpreter;
  bool capped;
}

/// Enriches REST log responses and live `run.output` frames with neutral
/// [TranscriptEntry] items using the attempt's resolved node interpreter.
final class RunTranscriptService {
  /// Creates a run transcript service and subscribes to [RunLogStore.outputs].
  new({
    required this._runs,
    required this._events,
    required this._logStore,
    required this._nodes,
    this._maxLiveAttempts = 64,
  }) {
    _subscription = _logStore.outputs.listen((payload) {
      _chain = _chain.then((_) => _handleLive(payload));
    });
  }

  static const int _eventPageSize = 1000;
  static final _log = Logger('run_transcript_service');

  final RunRepository _runs;
  final RunEventRepository _events;
  final RunLogStore _logStore;
  final NodeRegistry _nodes;
  final int _maxLiveAttempts;

  final StreamController<RunOutputPayload> _controller =
      StreamController<RunOutputPayload>.broadcast();
  final Map<_AttemptKey, _LiveAttemptState> _liveStates =
      <_AttemptKey, _LiveAttemptState>{};

  late final StreamSubscription<RunOutputPayload> _subscription;
  Future<void> _chain = Future<void>.value();

  /// Broadcast stream of live output frames enriched with `transcript` and
  /// `rawLogTruncated`.
  Stream<RunOutputPayload> get outputs => _controller.stream;

  /// Builds the transcript for [response] of [run].
  ///
  /// When [tailed] is `true`, the full attempt log is replayed up to
  /// `response.offset` so stateful interpreters preserve original entry ids,
  /// and only entries whose `lastOffset` falls inside the tail window are
  /// returned.
  Future<RunNodeLogsResponse> withTranscript(
    Run run,
    RunNodeLogsResponse response, {
    required bool tailed,
  }) async {
    final raw = await _readFullPrefixIfTailed(response, tailed: tailed);
    final interpreter = await _interpreterFor(
      run,
      response.nodeId,
      response.attempt,
    );
    final fullTranscript = buildTranscript(interpreter, raw);

    final List<TranscriptEntry> transcript;
    if (!tailed) {
      transcript = fullTranscript;
    } else if (response.entries.isEmpty) {
      transcript = const <TranscriptEntry>[];
    } else {
      final minOffset = response.entries.first.offset;
      transcript = fullTranscript
          .where((entry) => entry.lastOffset >= minOffset)
          .toList(growable: false);
    }

    final rawLogTruncated = raw.any(_isTruncationMarkerEntry);
    return response.copyWith(
      transcript: transcript,
      rawLogTruncated: rawLogTruncated,
    );
  }

  /// Cancels the raw log subscription, drains pending live frames, and closes
  /// [outputs].
  Future<void> close() async {
    await _subscription.cancel();
    await _chain;
    await _controller.close();
  }

  Future<List<RunLogEntry>> _readFullPrefixIfTailed(
    RunNodeLogsResponse response, {
    required bool tailed,
  }) async {
    if (!tailed) return response.entries;
    final fullResult = await _logStore.readLogs(
      runId: response.runId,
      nodeId: response.nodeId,
      attempt: response.attempt,
    );
    if (fullResult case Success(:final value)) {
      return value.entries
          .where((entry) => entry.offset <= response.offset)
          .toList(growable: false);
    }
    return response.entries;
  }

  Future<TranscriptInterpreter> _interpreterFor(
    Run run,
    String nodeId,
    int attempt,
  ) async {
    final eventsResult = await _loadAllEvents(run.id);
    if (eventsResult case FailureResult()) {
      _log.warning(
        LogEvent(
          'run_transcript.harness_lookup_failed',
          fields: {'runId': run.id, 'nodeId': nodeId, 'attempt': attempt},
        ),
      );
      return const PlainTextTranscriptInterpreter();
    }

    final events = (eventsResult as Success<List<RunEvent>>).value;
    final typeId = nodeTypeForAttempt(
      run: run,
      events: events,
      nodeId: nodeId,
      attempt: attempt,
    );
    final node = typeId == null ? null : _nodes.createOrNull(typeId);
    return node?.createTranscriptInterpreter() ??
        const PlainTextTranscriptInterpreter();
  }

  Future<Result<List<RunEvent>>> _loadAllEvents(String runId) async {
    final all = <RunEvent>[];
    int? afterSequence;
    while (true) {
      final pageResult = await _events.listForRun(
        runId,
        afterSequence: afterSequence,
        limit: _eventPageSize,
      );
      if (pageResult
          case FailureResult<({List<RunEvent> items, int lastSequence})>(
            :final failure,
          )) {
        return FailureResult(failure);
      }
      final page =
          (pageResult as Success<({List<RunEvent> items, int lastSequence})>)
              .value;
      all.addAll(page.items);
      if (page.items.length < _eventPageSize) {
        return Success(all);
      }
      afterSequence = page.lastSequence;
    }
  }

  Future<void> _handleLive(RunOutputPayload payload) async {
    if (_controller.isClosed) return;
    try {
      final key = (payload.runId, payload.nodeId, payload.attempt);
      final state = _liveStates[key] ?? await _primeState(key, payload.offset);

      if (state.capped) {
        _controller.add(
          payload.copyWith(
            transcript: const <TranscriptEntry>[],
            rawLogTruncated: true,
          ),
        );
        return;
      }

      final entries = state.interpreter.interpret(
        RunLogEntry(
          stream: payload.stream,
          chunk: payload.chunk,
          timestamp: payload.timestamp,
          offset: payload.offset,
        ),
      );
      if (_isTruncationMarkerPayload(payload)) {
        state.capped = true;
      }
      _controller.add(
        payload.copyWith(transcript: entries, rawLogTruncated: state.capped),
      );
    } on Object {
      _log.warning(
        LogEvent(
          'run_transcript.live_failed',
          fields: {
            'runId': payload.runId,
            'nodeId': payload.nodeId,
            'attempt': payload.attempt,
          },
        ),
      );
      if (!_controller.isClosed) {
        _controller.add(payload);
      }
    }
  }

  Future<_LiveAttemptState> _primeState(
    _AttemptKey key,
    int currentOffset,
  ) async {
    final (runId, nodeId, attempt) = key;
    final runResult = await _runs.getById(runId);
    final TranscriptInterpreter interpreter;
    if (runResult case Success(:final value)) {
      interpreter = await _interpreterFor(value, nodeId, attempt);
    } else {
      _log.warning(
        LogEvent(
          'run_transcript.harness_lookup_failed',
          fields: {'runId': runId, 'nodeId': nodeId, 'attempt': attempt},
        ),
      );
      interpreter = const PlainTextTranscriptInterpreter();
    }

    var capped = false;
    if (currentOffset > 1) {
      final historyResult = await _logStore.readLogs(
        runId: runId,
        nodeId: nodeId,
        attempt: attempt,
      );
      if (historyResult case Success(:final value)) {
        for (final entry in value.entries) {
          if (entry.offset >= currentOffset) break;
          if (_isTruncationMarkerEntry(entry)) {
            capped = true;
            break;
          }
          interpreter.interpret(entry);
        }
      }
    }

    final state = _LiveAttemptState(interpreter: interpreter, capped: capped);
    _liveStates[key] = state;
    while (_liveStates.length > _maxLiveAttempts) {
      _liveStates.remove(_liveStates.keys.first);
    }
    return state;
  }

  static bool _isTruncationMarkerEntry(RunLogEntry entry) =>
      entry.stream == RunOutputStream.stderr &&
      entry.chunk == RunLogStore.truncationMarkerChunk;

  static bool _isTruncationMarkerPayload(RunOutputPayload payload) =>
      payload.stream == RunOutputStream.stderr &&
      payload.chunk == RunLogStore.truncationMarkerChunk;
}
