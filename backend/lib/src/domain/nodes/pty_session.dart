import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Unique key identifying a single PTY session for `(runId, nodeId, attempt)`.
typedef PtySessionKey = ({String runId, String nodeId, int attempt});

/// Fixed-capacity in-memory byte ring buffer for PTY scrollback replay.
final class PtyScrollbackBuffer {
  /// Creates a ring buffer with [capacityBytes] (defaults to 512 KiB).
  new({this.capacityBytes = defaultCapacityBytes})
    : assert(capacityBytes > 0, 'capacityBytes must be positive'),
      _buffer = Uint8List(capacityBytes);

  /// Default scrollback capacity: 512 KiB.
  static const int defaultCapacityBytes = 512 * 1024;

  /// Maximum number of bytes retained.
  final int capacityBytes;

  final Uint8List _buffer;
  int _start = 0;
  int _length = 0;

  /// Number of bytes currently stored in the buffer.
  int get length => _length;

  /// Appends [bytes] to the ring buffer, evicting oldest bytes when full.
  void append(List<int> bytes) {
    if (bytes.isEmpty) return;

    if (bytes.length >= capacityBytes) {
      final offset = bytes.length - capacityBytes;
      _buffer.setRange(0, capacityBytes, bytes, offset);
      _start = 0;
      _length = capacityBytes;
      return;
    }

    final writePos = (_start + _length) % capacityBytes;
    final spaceToEnd = capacityBytes - writePos;
    if (bytes.length <= spaceToEnd) {
      _buffer.setRange(writePos, writePos + bytes.length, bytes);
    } else {
      _buffer
        ..setRange(writePos, capacityBytes, bytes, 0)
        ..setRange(0, bytes.length - spaceToEnd, bytes, spaceToEnd);
    }

    final newLength = _length + bytes.length;
    if (newLength > capacityBytes) {
      final overflow = newLength - capacityBytes;
      _start = (_start + overflow) % capacityBytes;
      _length = capacityBytes;
    } else {
      _length = newLength;
    }
  }

  /// Returns a contiguous copy of all currently buffered bytes in order.
  Uint8List snapshot() {
    if (_length == 0) return Uint8List(0);
    final result = Uint8List(_length);
    final firstChunk = (_start + _length <= capacityBytes)
        ? _length
        : (capacityBytes - _start);
    result.setRange(0, firstChunk, _buffer, _start);
    if (firstChunk < _length) {
      result.setRange(firstChunk, _length, _buffer, 0);
    }
    return result;
  }
}

/// Handle to a live OS pseudo-terminal session.
abstract interface class PtySessionHandle {
  /// Session key `(runId, nodeId, attempt)`.
  PtySessionKey get key;

  /// Whether the PTY session is still running.
  bool get isActive;

  /// Writes raw input [bytes] to the PTY stdin.
  Future<void> writeInput(List<int> bytes);

  /// Resizes the PTY to [cols] columns and [rows] rows.
  Future<void> resize(int cols, int rows);

  /// Terminates the PTY session and its process tree.
  Future<void> terminate();
}

final class _SessionState {
  new({required this.handle, required int scrollbackCapacityBytes})
    : scrollback = PtyScrollbackBuffer(capacityBytes: scrollbackCapacityBytes);

  final PtySessionHandle handle;
  final PtyScrollbackBuffer scrollback;
  final BytesBuilder pending = BytesBuilder(copy: false);
  Timer? coalesceTimer;
}

/// Coordinates active PTY sessions, 512 KiB scrollback ring buffers, and
/// coalesced `pty.output` streaming for WebSocket subscribers.
final class PtySessionRegistry {
  /// Creates a PTY session registry.
  new({
    this.scrollbackCapacityBytes = PtyScrollbackBuffer.defaultCapacityBytes,
    this.coalesceWindow = defaultCoalesceWindow,
    this.maxCoalesceBytes = defaultMaxCoalesceBytes,
  });

  /// Default coalescing window (~60 fps).
  static const Duration defaultCoalesceWindow = Duration(milliseconds: 16);

  /// Default maximum coalesced chunk size (32 KiB).
  static const int defaultMaxCoalesceBytes = 32 * 1024;

  /// Ring-buffer capacity per session.
  final int scrollbackCapacityBytes;

  /// Coalescing delay before emitting buffered PTY output.
  final Duration coalesceWindow;

  /// Maximum buffered bytes before flushing immediately.
  final int maxCoalesceBytes;

  final Map<PtySessionKey, _SessionState> _sessions =
      <PtySessionKey, _SessionState>{};
  final StreamController<PtyOutputPayload> _outputs =
      StreamController<PtyOutputPayload>.broadcast();
  bool _disposed = false;

  /// Broadcast stream of coalesced `pty.output` payloads.
  Stream<PtyOutputPayload> get outputs => _outputs.stream;

  /// Registers an active PTY [handle].
  void registerSession(PtySessionHandle handle) {
    if (_disposed) return;
    _sessions[handle.key] = _SessionState(
      handle: handle,
      scrollbackCapacityBytes: scrollbackCapacityBytes,
    );
  }

  /// Appends raw PTY output [bytes] for [key], updating its scrollback ring
  /// buffer and scheduling coalesced emission on [outputs].
  void appendOutput(PtySessionKey key, List<int> bytes) {
    if (_disposed || bytes.isEmpty) return;
    final state = _sessions[key];
    if (state == null) return;

    state.scrollback.append(bytes);
    state.pending.add(bytes);

    if (state.pending.length >= maxCoalesceBytes) {
      _flush(key, state);
      return;
    }

    state.coalesceTimer ??= Timer(coalesceWindow, () {
      _flush(key, state);
    });
  }

  /// Flushes any pending output and unregisters [key].
  Future<void> unregisterSession(PtySessionKey key) async {
    final state = _sessions.remove(key);
    if (state == null) return;
    _flush(key, state);
  }

  /// Returns a snapshot of the scrollback ring buffer for [key], or `null` if
  /// no active session exists.
  Uint8List? getScrollbackSnapshot(PtySessionKey key) =>
      _sessions[key]?.scrollback.snapshot();

  /// Whether [key] currently has an active PTY session.
  bool isActive(PtySessionKey key) => _sessions[key]?.handle.isActive ?? false;

  /// Writes [bytes] to the active PTY session for [key].
  Future<Result<void>> writeInput(PtySessionKey key, List<int> bytes) async {
    final state = _sessions[key];
    if (state == null || !state.handle.isActive) {
      return FailureResult(
        ConflictFailure(
          'PTY session (${key.runId}, ${key.nodeId}, ${key.attempt}) is not '
          'active.',
        ),
      );
    }
    await state.handle.writeInput(bytes);
    return const Success(null);
  }

  /// Resizes the active PTY session for [key] (last-writer-wins).
  Future<Result<void>> resize(
    PtySessionKey key, {
    required int cols,
    required int rows,
  }) async {
    final state = _sessions[key];
    if (state == null || !state.handle.isActive) {
      return FailureResult(
        ConflictFailure(
          'PTY session (${key.runId}, ${key.nodeId}, ${key.attempt}) is not '
          'active.',
        ),
      );
    }
    await state.handle.resize(cols, rows);
    return const Success(null);
  }

  /// Terminates the active PTY session for [key] if present.
  Future<void> terminateSession(PtySessionKey key) async {
    final state = _sessions[key];
    if (state == null || !state.handle.isActive) return;
    await state.handle.terminate();
  }

  void _flush(PtySessionKey key, _SessionState state) {
    state.coalesceTimer?.cancel();
    state.coalesceTimer = null;
    if (state.pending.isEmpty || _outputs.isClosed) return;
    final bytes = state.pending.takeBytes();
    _outputs.add(
      PtyOutputPayload(
        runId: key.runId,
        nodeId: key.nodeId,
        attempt: key.attempt,
        data: base64Encode(bytes),
        timestamp: DateTime.now().toUtc(),
      ),
    );
  }

  /// Releases all timers and closes the output stream.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _sessions.entries) {
      entry.value.coalesceTimer?.cancel();
      entry.value.coalesceTimer = null;
    }
    _sessions.clear();
    await _outputs.close();
  }
}
