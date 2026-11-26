import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Port the graph engine uses to snapshot and roll back a run's workspace
/// (ADR 0004).
///
/// Implemented by `ShadowSnapshotService`; the engine depends on this seam so
/// it can be tested without a shadow git repository.
abstract interface class SnapshotService {
  /// Captures a snapshot of [targetFolder] for [runId], tagged with [nodeId].
  Future<Result<Snapshot>> captureSnapshot({
    required String runId,
    required String targetFolder,
    String? nodeId,
    SnapshotKind kind = SnapshotKind.preNode,
  });

  /// Lists all snapshots of [runId] in chronological order.
  Future<Result<RunSnapshotsResponse>> listSnapshots(String runId);

  /// Restores the workspace of [runId] to [snapshotId]. The run must not be
  /// `running`.
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId,
  );
}
