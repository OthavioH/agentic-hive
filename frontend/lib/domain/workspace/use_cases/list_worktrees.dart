import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists the primary checkout and worktrees for a registered workspace.
final class ListWorktrees {
  /// Creates a [ListWorktrees] use case backed by [_repository].
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Executes the use case for [workspaceId].
  Future<Result<List<Worktree>>> call(String workspaceId) =>
      _repository.listWorktrees(workspaceId);
}
