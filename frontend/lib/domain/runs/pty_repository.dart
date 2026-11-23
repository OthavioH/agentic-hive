import 'package:agentic_hive_frontend/core/result/result.dart';

/// Repository contract for subscribing to and interacting with active PTY
/// sessions over the backend WebSocket.
abstract interface class PtyRepository {
  /// Subscribes to `pty.output` frames (and initial scrollback replay) for
  /// `(runId, nodeId, attempt)`.
  Future<Result<void>> subscribe({
    required String runId,
    required String nodeId,
    required int attempt,
  });

  /// Unsubscribes from `pty.output` frames for `(runId, nodeId, attempt)`.
  Future<Result<void>> unsubscribe({
    required String runId,
    required String nodeId,
    required int attempt,
  });

  /// Sends raw input [bytes] to the active PTY for `(runId, nodeId, attempt)`.
  Future<Result<void>> sendInput({
    required String runId,
    required String nodeId,
    required int attempt,
    required List<int> bytes,
  });

  /// Resizes the active PTY for `(runId, nodeId, attempt)` to [cols] x [rows].
  Future<Result<void>> resize({
    required String runId,
    required String nodeId,
    required int attempt,
    required int cols,
    required int rows,
  });
}
