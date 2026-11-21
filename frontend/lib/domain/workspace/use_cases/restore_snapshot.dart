import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Restores a run's workspace to a snapshot.
final class RestoreSnapshot {
  /// Creates a [RestoreSnapshot] use case backed by [_repository].
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Executes the use case for [snapshotId] of run [runId].
  Future<Result<RestoreSnapshotResponse>> call(
    String runId,
    String snapshotId,
  ) => _repository.restoreSnapshot(runId, snapshotId);
}
