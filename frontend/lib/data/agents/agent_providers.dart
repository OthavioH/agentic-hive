import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/data/agents/agent_repository_impl.dart';
import 'package:agentic_hive_frontend/data/agents/agents_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_providers.g.dart';

/// Provides the [AgentsRemoteDataSource] backed by [backendClientProvider].
@riverpod
AgentsRemoteDataSource agentsRemoteDataSource(Ref ref) {
  return AgentsRemoteDataSource(ref.watch(backendClientProvider));
}

/// Provides the [AgentRepository] implementation, forwarding live
/// `agents.changed` WebSocket events from [backendConnectionProvider].
@riverpod
AgentRepository agentRepository(Ref ref) {
  final controller = StreamController<AgentsChangedPayload>.broadcast();
  StreamSubscription<WsEnvelope>? sessionSub;

  void attachSession(BackendConnectionState conn) {
    final session = conn.sessionOrNull;
    unawaited(sessionSub?.cancel());
    sessionSub = null;
    if (session == null) return;
    sessionSub = session.messages.listen((envelope) {
      if (envelope.type != WsMessageType.agentsChanged) return;
      try {
        controller.add(AgentsChangedPayload.fromJson(envelope.payload));
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

  return AgentRepositoryImpl(
    remoteDataSource: ref.watch(agentsRemoteDataSourceProvider),
    changesStream: controller.stream,
  );
}
