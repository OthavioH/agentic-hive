import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workflow_deletion_providers.g.dart';

/// Provides the live feed of finished workflow deletions, forwarding
/// `workflow.deleted` and `workflow.delete.failed` from
/// [backendConnectionProvider].
@riverpod
WorkflowDeletionEventsSource workflowDeletionEventsSource(Ref ref) {
  final controller = StreamController<WorkflowDeletionFinished>.broadcast();
  StreamSubscription<WsEnvelope>? sessionSub;

  void attachSession(BackendConnectionState conn) {
    unawaited(sessionSub?.cancel());
    sessionSub = null;
    final session = conn.sessionOrNull;
    if (session == null) return;
    sessionSub = session.messages.listen((envelope) {
      final finished = decodeWorkflowDeletionEvent(envelope);
      if (finished != null) controller.add(finished);
    });
  }

  attachSession(ref.read(backendConnectionProvider));
  ref
    ..listen(backendConnectionProvider, (_, next) => attachSession(next))
    ..onDispose(() {
      unawaited(sessionSub?.cancel());
      unawaited(controller.close());
    });
  return _StreamWorkflowDeletionEventsSource(controller.stream);
}

final class _StreamWorkflowDeletionEventsSource
    implements WorkflowDeletionEventsSource {
  const new(this.finished);

  @override
  final Stream<WorkflowDeletionFinished> finished;
}
