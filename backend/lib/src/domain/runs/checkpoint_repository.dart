import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persistence contract for append-only [Checkpoint]s of a run.
abstract interface class CheckpointRepository {
  /// Appends a new checkpoint for [runId] with a monotonic `sequence`.
  ///
  /// When [sequence] is provided, it must equal the next expected sequence
  /// (`max + 1`); otherwise the next sequence is assigned atomically.
  Future<Result<Checkpoint>> append({
    required String id,
    required String runId,
    required List<String> pendingNodeIds,
    required Map<String, int> attemptsByEdge,
    required int circuitBreakerCount,
    required Map<String, JsonMap> nodeOutputs,
    required DateTime createdAt,
    String? completedNodeId,
    int? sequence,
  });

  /// Lists all checkpoints for [runId] ordered by `sequence ASC`.
  Future<Result<List<Checkpoint>>> listForRun(String runId);

  /// Returns the latest checkpoint for [runId] by highest `sequence`, or `null`
  /// if no checkpoints exist for that run.
  Future<Result<Checkpoint?>> getLatestForRun(String runId);
}
