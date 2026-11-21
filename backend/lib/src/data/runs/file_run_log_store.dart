import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// File-backed [RunLogStore] writing JSONL logs under
/// `<runsDir>/<runId>/logs/<encodedNodeId>__<attempt>.jsonl`.
final class FileRunLogStore implements RunLogStore {
  /// Creates a file-backed run log store under [_runsDir].
  new({required this._runsDir, p.Context? pathContext})
    : _pathContext = pathContext ?? p.context;

  static final _log = Logger('run_log_store');

  final String _runsDir;
  final p.Context _pathContext;
  final StreamController<RunOutputPayload> _controller =
      StreamController<RunOutputPayload>.broadcast();

  /// Serializes writes per log file path so concurrent lines never interleave.
  final Map<String, Future<void>> _writeChains = <String, Future<void>>{};

  @override
  Stream<RunOutputPayload> get outputs => _controller.stream;

  @override
  Future<void> appendOutput({
    required String runId,
    required String nodeId,
    required int attempt,
    required RunOutputStream stream,
    required String chunk,
    required DateTime timestamp,
  }) async {
    final utcTimestamp = timestamp.toUtc();
    if (!_controller.isClosed) {
      _controller.add(
        RunOutputPayload(
          runId: runId,
          nodeId: nodeId,
          attempt: attempt,
          stream: stream,
          chunk: chunk,
          timestamp: utcTimestamp,
        ),
      );
    }

    final filePath = _logFilePath(runId, nodeId, attempt);
    final entry = RunLogEntry(
      stream: stream,
      chunk: chunk,
      timestamp: utcTimestamp,
    );
    final line = '${jsonEncode(entry.toJson())}\n';

    final previous = _writeChains[filePath] ?? Future<void>.value();
    final next = previous
        .catchError((Object _) {})
        .then((_) => _writeLine(filePath, line));
    _writeChains[filePath] = next;
    await next;
    if (identical(_writeChains[filePath], next)) {
      unawaited(_writeChains.remove(filePath));
    }
  }

  Future<void> _writeLine(String filePath, String line) async {
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } on FileSystemException catch (error) {
      _log.warning(
        LogEvent(
          'run_logs.write_failed',
          fields: {'path': filePath, 'error': error.message},
        ),
      );
    }
  }

  @override
  Future<Result<RunNodeLogsResponse>> readLogs({
    required String runId,
    required String nodeId,
    int? attempt,
    int? tailLines,
  }) async {
    if (attempt != null && attempt < 1) {
      return const FailureResult(
        ValidationFailure('Query parameter "attempt" must be >= 1.'),
      );
    }
    if (tailLines != null && tailLines <= 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "tail" must be greater than 0.'),
      );
    }

    try {
      final logsDir = Directory(_logsDirPath(runId));
      final availableAttempts = await _listAttempts(logsDir, nodeId);
      final targetAttempt =
          attempt ?? (availableAttempts.isEmpty ? 1 : availableAttempts.last);

      final filePath = _logFilePath(runId, nodeId, targetAttempt);
      await (_writeChains[filePath] ?? Future<void>.value());

      final file = File(filePath);
      if (!file.existsSync()) {
        return Success(
          RunNodeLogsResponse(
            runId: runId,
            nodeId: nodeId,
            attempt: targetAttempt,
            availableAttempts: availableAttempts,
          ),
        );
      }

      final lines = await file.readAsLines();
      final entries = <RunLogEntry>[];
      for (final rawLine in lines) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is JsonMap) {
          entries.add(RunLogEntry.fromJson(decoded));
        }
      }

      var truncated = false;
      final List<RunLogEntry> resultEntries;
      if (tailLines != null && entries.length > tailLines) {
        truncated = true;
        resultEntries = entries.sublist(entries.length - tailLines);
      } else {
        resultEntries = entries;
      }

      return Success(
        RunNodeLogsResponse(
          runId: runId,
          nodeId: nodeId,
          attempt: targetAttempt,
          availableAttempts: availableAttempts,
          entries: resultEntries,
          truncated: truncated,
        ),
      );
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to read logs for run "$runId", node "$nodeId".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<void> deleteRunLogs(String runId) async {
    final pending = _writeChains.entries
        .where((e) => e.key.startsWith(_runDirPath(runId)))
        .map((e) => e.value)
        .toList(growable: false);
    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }

    final dir = Directory(_runDirPath(runId));
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException catch (error) {
        _log.warning(
          LogEvent(
            'run_logs.delete_failed',
            fields: {'runId': runId, 'error': error.message},
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    if (_writeChains.isNotEmpty) {
      await Future.wait(_writeChains.values.toList(growable: false));
    }
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  String _runDirPath(String runId) =>
      _pathContext.join(_runsDir, Uri.encodeComponent(runId));

  String _logsDirPath(String runId) =>
      _pathContext.join(_runDirPath(runId), 'logs');

  String _encodedPrefix(String nodeId) => '${Uri.encodeComponent(nodeId)}__';

  String _logFilePath(String runId, String nodeId, int attempt) => _pathContext
      .join(_logsDirPath(runId), '${_encodedPrefix(nodeId)}$attempt.jsonl');

  Future<List<int>> _listAttempts(Directory logsDir, String nodeId) async {
    if (!logsDir.existsSync()) return const <int>[];
    final prefix = _encodedPrefix(nodeId);
    final attempts = <int>[];
    await for (final entity in logsDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = _pathContext.basename(entity.path);
      if (!name.startsWith(prefix) || !name.endsWith('.jsonl')) continue;
      final attemptStr = name.substring(
        prefix.length,
        name.length - '.jsonl'.length,
      );
      final parsed = int.tryParse(attemptStr);
      if (parsed != null && parsed >= 1) {
        attempts.add(parsed);
      }
    }
    attempts.sort();
    return attempts;
  }
}
