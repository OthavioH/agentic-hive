import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/pty_repository.dart';

/// Sends raw terminal input bytes to an active PTY session.
final class SendPtyInput {
  /// Creates a [SendPtyInput] use case backed by [_repository].
  const new(this._repository);

  final PtyRepository _repository;

  /// Sends [bytes] to `(runId, nodeId, attempt)`.
  Future<Result<void>> call({
    required String runId,
    required String nodeId,
    required int attempt,
    required List<int> bytes,
  }) => _repository.sendInput(
    runId: runId,
    nodeId: nodeId,
    attempt: attempt,
    bytes: bytes,
  );
}
