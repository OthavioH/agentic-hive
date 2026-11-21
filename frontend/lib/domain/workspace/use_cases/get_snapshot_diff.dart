import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches the changed files of one snapshot.
final class GetSnapshotDiff {
  /// Creates a [GetSnapshotDiff] use case backed by [_repository].
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Executes the use case for [snapshotId] of run [runId].
  Future<Result<SnapshotDiff>> call(String runId, String snapshotId) =>
      _repository.getSnapshotDiff(runId, snapshotId);
}
