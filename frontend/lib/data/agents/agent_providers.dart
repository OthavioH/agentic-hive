import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/data/agents/agent_repository_impl.dart';
import 'package:agentic_hive_frontend/data/agents/agents_migration_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/agents/agents_migration_repository_impl.dart';
import 'package:agentic_hive_frontend/data/agents/agents_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/domain/agents/agents_migration_repository.dart';
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

  String? lastEffectiveAgentsDir;

  void attachSession(BackendConnectionState conn) {
    final session = conn.sessionOrNull;
    unawaited(sessionSub?.cancel());
    sessionSub = null;
    if (session == null) return;
    sessionSub = session.messages.listen((envelope) {
      if (envelope.type == WsMessageType.agentsChanged) {
        try {
          controller.add(AgentsChangedPayload.fromJson(envelope.payload));
        } on FormatException {
          // Ignore malformed WebSocket event payloads.
        }
      } else if (envelope.type == WsMessageType.settingsUpdated) {
        try {
          final payload = SettingsUpdatedPayload.fromJson(envelope.payload);
          final nextDir = payload.settings.effectiveAgentsDir;
          if (lastEffectiveAgentsDir != nextDir) {
            lastEffectiveAgentsDir = nextDir;
            controller.add(
              const AgentsChangedPayload(
                kind: AgentChangeKind.updated,
                id: '*',
              ),
            );
          }
        } on FormatException {
          // Ignore malformed WebSocket event payloads.
        }
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

/// Provides the [AgentsMigrationRepository] for the global agents move.
@riverpod
AgentsMigrationRepository agentsMigrationRepository(Ref ref) =>
    AgentsMigrationRepositoryImpl(
      AgentsMigrationRemoteDataSource(ref.watch(backendClientProvider)),
    );
