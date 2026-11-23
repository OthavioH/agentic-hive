import 'package:agentic_hive_backend/src/domain/workspace/workspace_events.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [WorkspaceEvents] that broadcasts `workspaces.changed` and
/// `worktrees.changed` frames to every open WebSocket connection.
final class WsWorkspaceEvents implements WorkspaceEvents {
  /// Creates a publisher that broadcasts through [_registry].
  new(this._registry, {String Function()? generateId})
    : _generateId = generateId ?? randomId;

  final ConnectionRegistry _registry;
  final String Function() _generateId;

  @override
  void workspaceChanged(
    WorkspaceChangeKind kind,
    String id, {
    Workspace? workspace,
  }) => _registry.broadcast(
    WsEnvelope(
      type: WsMessageType.workspacesChanged,
      id: _generateId(),
      payload: WorkspacesChangedPayload(
        kind: kind,
        id: id,
        workspace: workspace,
      ).toJson(),
    ),
  );

  @override
  void worktreeChanged(
    WorktreeChangeKind kind,
    String workspaceId,
    String worktreeId, {
    Worktree? worktree,
  }) => _registry.broadcast(
    WsEnvelope(
      type: WsMessageType.worktreesChanged,
      id: _generateId(),
      payload: WorktreesChangedPayload(
        kind: kind,
        workspaceId: workspaceId,
        worktreeId: worktreeId,
        worktree: worktree,
      ).toJson(),
    ),
  );
}
