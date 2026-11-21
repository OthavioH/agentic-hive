import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists the snapshots recorded for a run.
final class ListRunSnapshots {
  /// Creates a [ListRunSnapshots] use case backed by [_repository].
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Executes the use case for run [runId].
  Future<Result<List<Snapshot>>> call(String runId) =>
      _repository.listSnapshots(runId);
}
