import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Publishes workspace and worktree changes so clients can keep their view
/// live (ADR 0022).
abstract interface class WorkspaceEvents {
  /// Reports that [workspace] was registered or updated, or that the workspace
  /// [id] was unregistered ([workspace] is then null).
  void workspaceChanged(
    WorkspaceChangeKind kind,
    String id, {
    Workspace? workspace,
  });

  /// Reports that a worktree of [workspaceId] was created or removed.
  /// [worktree] is null for a removal.
  void worktreeChanged(
    WorktreeChangeKind kind,
    String workspaceId,
    String worktreeId, {
    Worktree? worktree,
  });
}
