import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_repository_impl.dart';
import 'package:agentic_hive_frontend/data/pauses/pauses_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pause_providers.g.dart';

/// Provides the [PausesRemoteDataSource] backed by [backendClientProvider].
@Riverpod(keepAlive: true)
PausesRemoteDataSource pausesRemoteDataSource(Ref ref) {
  return PausesRemoteDataSource(ref.watch(backendClientProvider));
}

/// Provides the [PauseRepository] implementation, forwarding `pause.created`
/// and `pause.resolved` WebSocket events and syncing on connect/reconnect.
@Riverpod(keepAlive: true)
PauseRepository pauseRepository(Ref ref) {
  final eventsController = StreamController<PauseEvent>.broadcast();
  StreamSubscription<WsEnvelope>? sessionSub;
  BackendWebSocketSession? attachedSession;

  final repository = PauseRepositoryImpl(
    remoteDataSource: ref.watch(pausesRemoteDataSourceProvider),
    eventsStream: eventsController.stream,
  );

  void attachSession(BackendConnectionState conn) {
    final session = conn.sessionOrNull;
    if (identical(session, attachedSession)) return;
    attachedSession = session;
    unawaited(sessionSub?.cancel());
    sessionSub = null;
    if (session == null) return;

    sessionSub = session.messages.listen((envelope) {
      if (envelope.type == WsMessageType.pauseCreated) {
        try {
          final payload = PauseCreatedPayload.fromJson(envelope.payload);
          eventsController.add(PauseCreatedEvent(payload.pause));
        } on FormatException {
          // Ignore malformed WebSocket event payloads.
        }
      } else if (envelope.type == WsMessageType.pauseResolved) {
        try {
          final payload = PauseResolvedPayload.fromJson(envelope.payload);
          eventsController.add(PauseResolvedEvent(payload.pause));
        } on FormatException {
          // Ignore malformed WebSocket event payloads.
        }
      }
    });

    eventsController.add(const PauseSyncRequestedEvent());
  }

  attachSession(ref.read(backendConnectionProvider));
  if (attachedSession == null) {
    unawaited(repository.syncPendingCount());
  }

  ref
    ..listen(backendConnectionProvider, (_, next) => attachSession(next))
    ..onDispose(() {
      unawaited(sessionSub?.cancel());
      unawaited(eventsController.close());
      unawaited(repository.dispose());
    });

  return repository;
}
