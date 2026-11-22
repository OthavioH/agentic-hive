import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/pty_repository.dart';

/// Resizes an active PTY session to the given cell dimensions.
final class ResizePty {
  /// Creates a [ResizePty] use case backed by [_repository].
  const new(this._repository);

  final PtyRepository _repository;

  /// Resizes `(runId, nodeId, attempt)` to [cols] by [rows].
  Future<Result<void>> call({
    required String runId,
    required String nodeId,
    required int attempt,
    required int cols,
    required int rows,
  }) => _repository.resize(
    runId: runId,
    nodeId: nodeId,
    attempt: attempt,
    cols: cols,
    rows: rows,
  );
}
