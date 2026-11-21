import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/pty_repository.dart';

/// Subscribes to live PTY output and scrollback replay for a node attempt.
final class SubscribePty {
  /// Creates a [SubscribePty] use case backed by [_repository].
  const new(this._repository);

  final PtyRepository _repository;

  /// Executes the subscription for `(runId, nodeId, attempt)`.
  Future<Result<void>> call({
    required String runId,
    required String nodeId,
    required int attempt,
  }) => _repository.subscribe(runId: runId, nodeId: nodeId, attempt: attempt);
}
