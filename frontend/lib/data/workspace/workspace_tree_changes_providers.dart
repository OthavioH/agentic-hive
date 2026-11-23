import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_tree_changes.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_tree_changes_providers.g.dart';

/// Provides the [WorkspaceTreeChangesSource], forwarding run, pause,
/// workspace and worktree WebSocket events from [backendConnectionProvider]
/// and signalling a resync whenever the connection is re-established.
@riverpod
WorkspaceTreeChangesSource workspaceTreeChangesSource(Ref ref) {
  final controller = StreamController<WorkspaceTreeChange>.broadcast();
  StreamSubscription<WsEnvelope>? sessionSub;
  BackendWebSocketSession? attachedSession;
  var hasAttachedOnce = false;

  void attachSession(BackendConnectionState conn) {
    final session = conn.sessionOrNull;
    if (identical(session, attachedSession)) return;
    attachedSession = session;
    unawaited(sessionSub?.cancel());
    sessionSub = null;
    if (session == null) return;
    sessionSub = session.messages.listen((envelope) {
      final change = workspaceTreeChangeFor(envelope);
      if (change != null) controller.add(change);
    });
    if (hasAttachedOnce) controller.add(WorkspaceTreeChange.resync);
    hasAttachedOnce = true;
  }

  attachSession(ref.read(backendConnectionProvider));
  ref
    ..listen(backendConnectionProvider, (_, next) => attachSession(next))
    ..onDispose(() {
      unawaited(sessionSub?.cancel());
      unawaited(controller.close());
    });
  return _StreamWorkspaceTreeChangesSource(controller.stream);
}

final class _StreamWorkspaceTreeChangesSource
    implements WorkspaceTreeChangesSource {
  const new(this.changes);

  @override
  final Stream<WorkspaceTreeChange> changes;
}
