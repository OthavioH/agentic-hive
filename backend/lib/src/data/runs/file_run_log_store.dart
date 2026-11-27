import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final class _OpenAttemptLog {
  new({
    required this.filePath,
    required this.sink,
    required this.nextOffset,
    required this.bytesWritten,
    required this.capReached,
  });

  final String filePath;
  final IOSink sink;
  int nextOffset;
  int bytesWritten;
  bool capReached;
}

/// File-backed [RunLogStore] writing JSONL logs under
/// `<runsDir>/<runId>/logs/<encodedNodeId>__<attempt>.jsonl`.
///
/// Keeps an open [IOSink] per active `(runId, nodeId, attempt)` stream,
/// enforces a per-file size cap ([maxLogFileBytes]) with a truncation marker
/// entry, assigns a 1-based monotonic `offset` to every persisted entry before
/// emitting it on [outputs], and reads tail lines from the end of the file.
final class FileRunLogStore implements RunLogStore {
  /// Creates a file-backed run log store under [_runsDir].
  new({
    required this._runsDir,
    p.Context? pathContext,
    this.maxLogFileBytes = defaultMaxLogFileBytes,
  }) : _pathContext = pathContext ?? p.context;

  /// Default maximum size in bytes per `(runId, nodeId, attempt)` log file
  /// (10 MiB).
  static const int defaultMaxLogFileBytes = 10 * 1024 * 1024;

  /// Marker chunk written once when a log file reaches [maxLogFileBytes].
  static const String truncationMarkerChunk = RunLogStore.truncationMarkerChunk;

  static const int _tailChunkBytes = 64 * 1024;
  static final _log = Logger('run_log_store');

  final String _runsDir;
  final p.Context _pathContext;

  /// Maximum size in bytes allowed for a single node attempt log file before
  /// further disk writes are truncated.
  final int maxLogFileBytes;

  final StreamController<RunOutputPayload> _controller =
      StreamController<RunOutputPayload>.broadcast(sync: true);

  /// Serializes operations per log file path so concurrent writes, flushes,
  /// and closes never interleave.
  final Map<String, Future<void>> _writeChains = <String, Future<void>>{};

  /// Kept-open sinks keyed by log file path.
  final Map<String, _OpenAttemptLog> _openLogs = <String, _OpenAttemptLog>{};

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
    final filePath = _logFilePath(runId, nodeId, attempt);

    await _enqueue(filePath, () async {
      final state = await _getOrOpenLog(filePath);
      if (state == null) return;

      if (state.capReached) {
        final offset = state.nextOffset++;
        _emitOutput(
          runId: runId,
          nodeId: nodeId,
          attempt: attempt,
          stream: stream,
          chunk: chunk,
          timestamp: utcTimestamp,
          offset: offset,
        );
        return;
      }

      final offset = state.nextOffset++;
      final entry = RunLogEntry(
        stream: stream,
        chunk: chunk,
        timestamp: utcTimestamp,
        offset: offset,
      );
      final encoded = utf8.encode('${jsonEncode(entry.toJson())}\n');

      if (maxLogFileBytes > 0 &&
          state.bytesWritten + encoded.length > maxLogFileBytes) {
        state.capReached = true;
        final markerEntry = RunLogEntry(
          stream: RunOutputStream.stderr,
          chunk: truncationMarkerChunk,
          timestamp: utcTimestamp,
          offset: offset,
        );
        final markerBytes = utf8.encode(
          '${jsonEncode(markerEntry.toJson())}\n',
        );
        try {
          state.sink.add(markerBytes);
          state.bytesWritten += markerBytes.length;
        } on Object catch (error) {
          _log.warning(
            LogEvent(
              'run_logs.write_failed',
              fields: {'path': filePath, 'error': '$error'},
            ),
          );
        }
        _emitOutput(
          runId: runId,
          nodeId: nodeId,
          attempt: attempt,
          stream: RunOutputStream.stderr,
          chunk: truncationMarkerChunk,
          timestamp: utcTimestamp,
          offset: offset,
        );
        return;
      }

      try {
        state.sink.add(encoded);
        state.bytesWritten += encoded.length;
      } on Object catch (error) {
        _log.warning(
          LogEvent(
            'run_logs.write_failed',
            fields: {'path': filePath, 'error': '$error'},
          ),
        );
      }

      _emitOutput(
        runId: runId,
        nodeId: nodeId,
        attempt: attempt,
        stream: stream,
        chunk: chunk,
        timestamp: utcTimestamp,
        offset: offset,
      );
    });
  }

  void _emitOutput({
    required String runId,
    required String nodeId,
    required int attempt,
    required RunOutputStream stream,
    required String chunk,
    required DateTime timestamp,
    required int offset,
  }) {
    if (_controller.isClosed) return;
    _controller.add(
      RunOutputPayload(
        runId: runId,
        nodeId: nodeId,
        attempt: attempt,
        stream: stream,
        chunk: chunk,
        timestamp: timestamp,
        offset: offset,
      ),
    );
  }

  Future<_OpenAttemptLog?> _getOrOpenLog(String filePath) async {
    final existing = _openLogs[filePath];
    if (existing != null) return existing;

    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      var nextOffset = 1;
      var bytesWritten = 0;
      var capReached = false;
      if (file.existsSync()) {
        bytesWritten = await file.length();
        final existingEntries = await _readEntriesFromFile(file, null);
        if (existingEntries.entries.isNotEmpty) {
          nextOffset = existingEntries.entries.last.offset + 1;
          capReached = existingEntries.capped;
        }
      }
      final sink = file.openWrite(mode: FileMode.append);
      final opened = _OpenAttemptLog(
        filePath: filePath,
        sink: sink,
        nextOffset: nextOffset,
        bytesWritten: bytesWritten,
        capReached: capReached,
      );
      _openLogs[filePath] = opened;
      return opened;
    } on FileSystemException catch (error) {
      _log.warning(
        LogEvent(
          'run_logs.open_failed',
          fields: {'path': filePath, 'error': error.message},
        ),
      );
      return null;
    }
  }

  Future<void> _enqueue(String filePath, Future<void> Function() action) async {
    final previous = _writeChains[filePath] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) => action());
    _writeChains[filePath] = next;
    await next;
    if (identical(_writeChains[filePath], next)) {
      unawaited(_writeChains.remove(filePath));
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
      await _enqueue(filePath, () async {
        final open = _openLogs[filePath];
        if (open != null) {
          await open.sink.flush();
        }
      });

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

      final readResult = await _readEntriesFromFile(file, tailLines);
      final open = _openLogs[filePath];
      final highestOffset = readResult.entries.isNotEmpty
          ? readResult.entries.last.offset
          : (open != null ? open.nextOffset - 1 : 0);

      return Success(
        RunNodeLogsResponse(
          runId: runId,
          nodeId: nodeId,
          attempt: targetAttempt,
          availableAttempts: availableAttempts,
          entries: readResult.entries,
          truncated:
              readResult.tailed ||
              readResult.capped ||
              (open?.capReached ?? false),
          offset: highestOffset,
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

  Future<({List<RunLogEntry> entries, bool tailed, bool capped})>
  _readEntriesFromFile(File file, int? tailLines) async {
    final raf = await file.open();
    try {
      final length = await raf.length();
      if (length == 0) {
        return (entries: const <RunLogEntry>[], tailed: false, capped: false);
      }

      var tailed = false;
      List<String> rawLines;
      if (tailLines == null) {
        final bytes = await raf.read(length);
        rawLines = const LineSplitter().convert(
          utf8.decode(bytes, allowMalformed: true),
        );
      } else {
        final tail = await _readTailLines(raf, length, tailLines);
        rawLines = tail.lines;
        tailed = tail.truncated;
      }

      final entries = <RunLogEntry>[];
      var capped = false;
      var fallbackOffset = 1;
      for (final rawLine in rawLines) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is JsonMap) {
          var entry = RunLogEntry.fromJson(decoded);
          if (entry.offset == 0) {
            entry = entry.copyWith(offset: fallbackOffset);
          }
          fallbackOffset = entry.offset + 1;
          if (entry.chunk == truncationMarkerChunk) {
            capped = true;
          }
          entries.add(entry);
        }
      }
      return (entries: entries, tailed: tailed, capped: capped);
    } finally {
      await raf.close();
    }
  }

  Future<({List<String> lines, bool truncated})> _readTailLines(
    RandomAccessFile raf,
    int fileLength,
    int tailLines,
  ) async {
    final chunks = <Uint8List>[];
    var position = fileLength;
    var newlineCount = 0;

    while (position > 0 && newlineCount <= tailLines) {
      final readSize = position >= _tailChunkBytes ? _tailChunkBytes : position;
      position -= readSize;
      await raf.setPosition(position);
      final chunk = await raf.read(readSize);
      chunks.add(chunk);
      for (var i = 0; i < chunk.length; i++) {
        if (chunk[i] == 0x0A) newlineCount++;
      }
    }

    final totalBytes = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final combined = Uint8List(totalBytes);
    var offset = 0;
    for (var i = chunks.length - 1; i >= 0; i--) {
      final chunk = chunks[i];
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    // If we stopped before the beginning of the file, drop the first partial
    // line up to its terminating newline so we only decode complete JSONL rows.
    var startByte = 0;
    if (position > 0) {
      final firstNewline = combined.indexOf(0x0A);
      if (firstNewline != -1) {
        startByte = firstNewline + 1;
      }
    }

    final text = utf8.decode(
      Uint8List.sublistView(combined, startByte),
      allowMalformed: true,
    );
    final allLines = const LineSplitter()
        .convert(text)
        .where((l) => l.trim().isNotEmpty)
        .toList(growable: false);

    if (allLines.length > tailLines) {
      return (
        lines: allLines.sublist(allLines.length - tailLines),
        truncated: true,
      );
    }
    return (lines: allLines, truncated: position > 0);
  }

  @override
  Future<void> deleteRunLogs(String runId) async {
    final runDirPrefix = _runDirPath(runId);
    final matchingPaths = <String>{
      ..._writeChains.keys.where((k) => k.startsWith(runDirPrefix)),
      ..._openLogs.keys.where((k) => k.startsWith(runDirPrefix)),
    };

    for (final filePath in matchingPaths) {
      await _enqueue(filePath, () async {
        final open = _openLogs.remove(filePath);
        if (open != null) {
          await open.sink.flush();
          await open.sink.close();
        }
      });
    }

    final dir = Directory(runDirPrefix);
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
    final paths = <String>{..._writeChains.keys, ..._openLogs.keys};
    for (final filePath in paths) {
      await _enqueue(filePath, () async {
        final open = _openLogs.remove(filePath);
        if (open != null) {
          await open.sink.flush();
          await open.sink.close();
        }
      });
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
