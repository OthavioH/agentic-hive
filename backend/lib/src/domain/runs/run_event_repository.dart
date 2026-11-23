import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persistence contract for append-only [RunEvent]s of a run.
abstract interface class RunEventRepository {
  /// Appends a new event for [runId] with a monotonic `sequence`.
  ///
  /// When [sequence] is provided, it must equal the next expected sequence
  /// (`max + 1`); otherwise the next sequence is assigned atomically.
  Future<Result<RunEvent>> append({
    required String id,
    required String runId,
    required RunEventType type,
    required DateTime createdAt,
    String? nodeId,
    String? edgeId,
    JsonMap payload = const {},
    int? sequence,
  });

  /// Lists events for [runId] ordered by `sequence ASC`, optionally starting
  /// strictly after [afterSequence] and capped at [limit].
  Future<Result<({List<RunEvent> items, int lastSequence})>> listForRun(
    String runId, {
    int? afterSequence,
    int? limit,
  });

  /// Returns currently executing node start timestamps keyed by
  /// `runId -> nodeId -> startedAt` for the given [runIds].
  ///
  /// A node is executing if its latest lifecycle event (`node.started`,
  /// `node.completed`, or `node.failed`) by `sequence` is `node.started`.
  Future<Result<Map<String, Map<String, DateTime>>>> findExecutingNodesForRuns(
    List<String> runIds,
  );
}
