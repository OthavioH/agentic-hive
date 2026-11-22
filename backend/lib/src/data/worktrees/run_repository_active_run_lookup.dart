import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/active_run_lookup.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [ActiveRunLookup] backed by the [RunRepository].
final class RunRepositoryActiveRunLookup implements ActiveRunLookup {
  /// Creates a lookup over [_runs].
  const new(this._runs);

  static const List<RunStatus> _activeStatuses = [
    RunStatus.running,
    RunStatus.paused,
    RunStatus.cancelling,
  ];

  final RunRepository _runs;

  @override
  Future<Result<Set<String>>> activeTargetFolders(String workspaceId) async {
    final folders = <String>{};
    for (final status in _activeStatuses) {
      final result = await _runs.listByStatus(status);
      switch (result) {
        case FailureResult<List<Run>>(:final failure):
          return FailureResult(failure);
        case Success<List<Run>>(:final value):
          for (final run in value) {
            if (run.workspaceId == workspaceId) {
              folders.add(run.worktreePath ?? run.workspacePath);
            }
          }
      }
    }
    return Success(folders);
  }
}
