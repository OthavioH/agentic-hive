import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workflow_deletion_providers.g.dart';

/// Provides the live feed of workflow deletions, forwarding
/// `workflow.deleted`, `workflow.delete.failed` and `workflow.delete.progress`
/// from [backendConnectionProvider].
@riverpod
WorkflowDeletionEventsSource workflowDeletionEventsSource(Ref ref) {
  final finished = StreamController<WorkflowDeletionFinished>.broadcast();
  final progress = StreamController<WorkflowDeletionStatus>.broadcast();
  StreamSubscription<WsEnvelope>? sessionSub;

  void attachSession(BackendConnectionState conn) {
    unawaited(sessionSub?.cancel());
    sessionSub = null;
    final session = conn.sessionOrNull;
    if (session == null) return;
    sessionSub = session.messages.listen((envelope) {
      final event = decodeWorkflowDeletionEvent(envelope);
      if (event != null) finished.add(event);
      final status = decodeWorkflowDeletionProgress(envelope);
      if (status != null) progress.add(status);
    });
  }

  attachSession(ref.read(backendConnectionProvider));
  ref
    ..listen(backendConnectionProvider, (_, next) => attachSession(next))
    ..onDispose(() {
      unawaited(sessionSub?.cancel());
      unawaited(finished.close());
      unawaited(progress.close());
    });
  return _StreamWorkflowDeletionEventsSource(finished.stream, progress.stream);
}

final class _StreamWorkflowDeletionEventsSource
    implements WorkflowDeletionEventsSource {
  const new(this.finished, this.progress);

  @override
  final Stream<WorkflowDeletionFinished> finished;

  @override
  final Stream<WorkflowDeletionStatus> progress;
}
