import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Removes a non-primary worktree from a registered workspace.
final class RemoveWorktree {
  /// Creates a [RemoveWorktree] use case backed by [_repository].
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Executes the use case for [worktreeId] inside [workspaceId].
  ///
  /// When [force] is `true`, uncommitted changes in the worktree are discarded.
  Future<Result<RemoveWorktreeResponse>> call(
    String workspaceId,
    String worktreeId, {
    bool force = false,
  }) => _repository.removeWorktree(workspaceId, worktreeId, force: force);
}
