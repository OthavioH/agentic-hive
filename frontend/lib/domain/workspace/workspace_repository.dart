import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for workspace capabilities and run snapshots.
abstract interface class WorkspaceRepository {
  /// Reports git availability and, when [path] is given, whether it is a git
  /// repository with commits.
  Future<Result<WorkspaceCapabilities>> getCapabilities({String? path});

  /// Lists the snapshots recorded for run [runId], oldest first.
  Future<Result<List<Snapshot>>> listSnapshots(String runId);

  /// Fetches the changed-file list of snapshot [snapshotId] of run [runId].
  Future<Result<SnapshotDiff>> getSnapshotDiff(String runId, String snapshotId);

  /// Restores the workspace of run [runId] to snapshot [snapshotId].
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId,
  );
}
