import 'package:agentic_hive_backend/src/core/result.dart';

/// Tells which folders of a workspace currently host an active run.
abstract interface class ActiveRunLookup {
  /// Returns the target folders (the worktree path, or the workspace root for
  /// direct runs) of every active run (`running`, `paused` or `cancelling`)
  /// that belongs to workspace [workspaceId].
  Future<Result<Set<String>>> activeTargetFolders(String workspaceId);
}
