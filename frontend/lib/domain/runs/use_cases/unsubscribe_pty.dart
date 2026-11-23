import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/pty_repository.dart';

/// Unsubscribes from live PTY output for a node attempt.
final class UnsubscribePty {
  /// Creates an [UnsubscribePty] use case backed by [_repository].
  const new(this._repository);

  final PtyRepository _repository;

  /// Executes the unsubscription for `(runId, nodeId, attempt)`.
  Future<Result<void>> call({
    required String runId,
    required String nodeId,
    required int attempt,
  }) => _repository.unsubscribe(runId: runId, nodeId: nodeId, attempt: attempt);
}
