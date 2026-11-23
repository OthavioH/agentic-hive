import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_changes_source.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workflow_providers.g.dart';

/// Provides the [WorkflowRemoteDataSource] backed by [backendClientProvider].
@riverpod
WorkflowRemoteDataSource workflowRemoteDataSource(Ref ref) {
  return HttpWorkflowRemoteDataSource(ref.watch(backendClientProvider));
}

/// Provides the [WorkflowRepository] interface.
@riverpod
WorkflowRepository workflowRepository(Ref ref) {
  return WorkflowRepositoryImpl(ref.watch(workflowRemoteDataSourceProvider));
}

/// Provides the [WorkflowChangesSource], forwarding `workflows.changed`
/// WebSocket events from [backendConnectionProvider].
@riverpod
WorkflowChangesSource workflowChangesSource(Ref ref) {
  final controller = StreamController<WorkflowsChangedPayload>.broadcast();
  StreamSubscription<WsEnvelope>? sessionSub;

  void attachSession(BackendConnectionState conn) {
    unawaited(sessionSub?.cancel());
    sessionSub = null;
    final session = conn.sessionOrNull;
    if (session == null) return;
    sessionSub = session.messages.listen((envelope) {
      if (envelope.type != WsMessageType.workflowsChanged) return;
      try {
        controller.add(WorkflowsChangedPayload.fromJson(envelope.payload));
      } on FormatException {
        // Ignore malformed WebSocket event payloads.
      }
    });
  }

  attachSession(ref.read(backendConnectionProvider));
  ref
    ..listen(backendConnectionProvider, (_, next) => attachSession(next))
    ..onDispose(() {
      unawaited(sessionSub?.cancel());
      unawaited(controller.close());
    });
  return _StreamWorkflowChangesSource(controller.stream);
}

final class _StreamWorkflowChangesSource implements WorkflowChangesSource {
  const new(this.changes);

  @override
  final Stream<WorkflowsChangedPayload> changes;
}
