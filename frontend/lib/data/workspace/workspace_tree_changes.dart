import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Maps a WebSocket [envelope] to the tree change it implies, or null when the
/// message does not affect the side rail tree.
///
/// Only run lifecycle events (`run.*`) matter: node and checkpoint events do
/// not change what the tree shows.
WorkspaceTreeChange? workspaceTreeChangeFor(WsEnvelope envelope) {
  switch (envelope.type) {
    case WsMessageType.runEvent:
      try {
        final event = RunEventPayload.fromJson(envelope.payload).event;
        return event.type.wireName.startsWith('run.')
            ? WorkspaceTreeChange.run
            : null;
      } on FormatException {
        return null;
      }
    case WsMessageType.pauseCreated || WsMessageType.pauseResolved:
      return WorkspaceTreeChange.pause;
    case WsMessageType.workspacesChanged:
      return WorkspaceTreeChange.workspace;
    case WsMessageType.worktreesChanged:
      return WorkspaceTreeChange.worktree;
    default:
      return null;
  }
}
