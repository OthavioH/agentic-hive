import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/data/overview/overview_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/overview/overview_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_event.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overview_providers.g.dart';

/// Provides the [OverviewRemoteDataSource] backed by [backendClientProvider].
@Riverpod(keepAlive: true)
OverviewRemoteDataSource overviewRemoteDataSource(Ref ref) {
  return OverviewRemoteDataSource(ref.watch(backendClientProvider));
}

/// Provides the [OverviewRepository] implementation, forwarding `run.event`,
/// `pause.created`, and `pause.resolved` WebSocket messages and requesting a
/// snapshot resync whenever the WebSocket reconnects.
@Riverpod(keepAlive: true)
OverviewRepository overviewRepository(Ref ref) {
  final eventsController = StreamController<OverviewEvent>.broadcast();
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
      if (envelope.type == WsMessageType.runEvent) {
        try {
          final payload = RunEventPayload.fromJson(envelope.payload);
          eventsController.add(OverviewRunEventReceived(payload.event));
        } on FormatException {
          // Ignore malformed WebSocket event payloads.
        }
      } else if (envelope.type == WsMessageType.pauseCreated) {
        try {
          final payload = PauseCreatedPayload.fromJson(envelope.payload);
          eventsController.add(OverviewPauseCreatedEvent(payload.pause));
        } on FormatException {
          // Ignore malformed WebSocket event payloads.
        }
      } else if (envelope.type == WsMessageType.pauseResolved) {
        try {
          final payload = PauseResolvedPayload.fromJson(envelope.payload);
          eventsController.add(OverviewPauseResolvedEvent(payload.pause));
        } on FormatException {
          // Ignore malformed WebSocket event payloads.
        }
      }
    });

    if (hasAttachedOnce) {
      eventsController.add(const OverviewSyncRequestedEvent());
    }
    hasAttachedOnce = true;
  }

  attachSession(ref.read(backendConnectionProvider));

  ref
    ..listen(backendConnectionProvider, (_, next) => attachSession(next))
    ..onDispose(() {
      unawaited(sessionSub?.cancel());
      unawaited(eventsController.close());
    });

  return OverviewRepositoryImpl(
    ref.watch(overviewRemoteDataSourceProvider),
    eventsController.stream,
  );
}
