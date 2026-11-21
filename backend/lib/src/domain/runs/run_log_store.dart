import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Port for persisting and streaming per-`(runId, nodeId, attempt)` raw
/// `stdout`/`stderr` output logs outside SQLite.
abstract interface class RunLogStore {
  /// Broadcast stream of live output chunks emitted by running nodes.
  Stream<RunOutputPayload> get outputs;

  /// Appends one output [chunk] for `(runId, nodeId, attempt)` to disk and
  /// publishes a [RunOutputPayload] on [outputs].
  Future<void> appendOutput({
    required String runId,
    required String nodeId,
    required int attempt,
    required RunOutputStream stream,
    required String chunk,
    required DateTime timestamp,
  });

  /// Reads stored log entries for `(runId, nodeId)`.
  ///
  /// When [attempt] is `null`, the latest available attempt is returned.
  /// When [tailLines] is provided, only the last [tailLines] entries are
  /// returned and [RunNodeLogsResponse.truncated] is set if older lines were
  /// omitted.
  Future<Result<RunNodeLogsResponse>> readLogs({
    required String runId,
    required String nodeId,
    int? attempt,
    int? tailLines,
  });

  /// Deletes all stored log files for [runId].
  Future<void> deleteRunLogs(String runId);

  /// Flushes pending writes and closes the output stream.
  Future<void> close();
}
