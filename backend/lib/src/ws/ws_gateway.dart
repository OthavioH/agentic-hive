import 'dart:async';

import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Accepts WebSocket connections on `GET /ws`.
///
/// On connect it registers the connection and sends `server.hello`. Every
/// frame must be a [WsEnvelope]; frames it cannot handle get an `error`
/// message back, and the connection stays open.
final class WsGateway {
  /// Creates the gateway; [_generateId] is injectable for tests.
  new({
    required this._registry,
    required this._pingInterval,
    required this._serverVersion,
    Stream<HarnessInfo>? harnessStatusUpdates,
    Stream<AppSettings>? settingsUpdates,
    Stream<RunEvent>? runEvents,
    Stream<RunOutputPayload>? runOutputs,
    this._generateId = randomId,
  }) {
    _harnessUpdatesSubscription = harnessStatusUpdates?.listen(
      _broadcastHarnessStatus,
    );
    _settingsUpdatesSubscription = settingsUpdates?.listen(
      _broadcastSettingsUpdated,
    );
    _runEventsSubscription = runEvents?.listen(_broadcastRunEvent);
    _runOutputsSubscription = runOutputs?.listen(_broadcastRunOutput);
  }

  static final _log = Logger('ws');

  final ConnectionRegistry _registry;
  final Duration _pingInterval;
  final String _serverVersion;
  final String Function() _generateId;
  StreamSubscription<HarnessInfo>? _harnessUpdatesSubscription;
  StreamSubscription<AppSettings>? _settingsUpdatesSubscription;
  StreamSubscription<RunEvent>? _runEventsSubscription;
  StreamSubscription<RunOutputPayload>? _runOutputsSubscription;

  /// Releases subscriptions held by the gateway.
  Future<void> close() async {
    await _harnessUpdatesSubscription?.cancel();
    _harnessUpdatesSubscription = null;
    await _settingsUpdatesSubscription?.cancel();
    _settingsUpdatesSubscription = null;
    await _runEventsSubscription?.cancel();
    _runEventsSubscription = null;
    await _runOutputsSubscription?.cancel();
    _runOutputsSubscription = null;
  }

  void _broadcastHarnessStatus(HarnessInfo harness) {
    _registry.broadcast(
      WsEnvelope(
        type: WsMessageType.harnessStatusUpdated,
        id: _generateId(),
        payload: HarnessStatusUpdatedPayload(harness: harness).toJson(),
      ),
    );
  }

  void _broadcastSettingsUpdated(AppSettings settings) {
    _registry.broadcast(
      WsEnvelope(
        type: WsMessageType.settingsUpdated,
        id: _generateId(),
        payload: SettingsUpdatedPayload(settings: settings).toJson(),
      ),
    );
  }

  void _broadcastRunEvent(RunEvent event) {
    _registry.broadcast(
      WsEnvelope(
        type: WsMessageType.runEvent,
        id: _generateId(),
        payload: RunEventPayload(event: event).toJson(),
      ),
    );
  }

  void _broadcastRunOutput(RunOutputPayload output) {
    _registry.broadcastToRun(
      output.runId,
      WsEnvelope(
        type: WsMessageType.runOutput,
        id: _generateId(),
        payload: output.toJson(),
      ),
    );
  }

  /// The shelf handler that upgrades `GET /ws`.
  ///
  /// A successful upgrade hijacks the connection (shelf throws a
  /// `HijackException`). Anything else gets the standard JSON error instead of
  /// the HTML page `shelf_web_socket` builds: `426` for a request that is not
  /// an upgrade, the original status for an invalid handshake.
  Handler get handler {
    final upgrade = webSocketHandler(
      _onConnection,
      pingInterval: _pingInterval,
    );
    return (request) async {
      final rejected = await upgrade(request);
      return rejected.statusCode == 404
          ? errorResponse(
              request,
              426,
              code: ApiErrorCode.upgradeRequired,
              message: 'This route only accepts WebSocket upgrade requests.',
            )
          : errorResponse(
              request,
              rejected.statusCode,
              code: ApiErrorCode.invalidWebSocketHandshake,
              message: 'Invalid WebSocket handshake.',
            );
    };
  }

  void _onConnection(WebSocketChannel channel, String? subprotocol) {
    final connection = WsConnection(id: _generateId(), channel: channel);
    _registry.add(connection);
    _log.info(
      LogEvent(
        'ws.connected',
        fields: {'connectionId': connection.id, 'open': _registry.count},
      ),
    );

    connection.send(
      WsEnvelope(
        type: WsMessageType.serverHello,
        id: _generateId(),
        payload: ServerHelloPayload(
          serverVersion: _serverVersion,
          protocolVersion: wsProtocolVersion,
        ).toJson(),
      ),
    );

    channel.stream.listen(
      (frame) => _onFrame(connection, frame),
      onDone: () => _onDone(connection),
      onError: (Object error, StackTrace stackTrace) => _log.warning(
        LogEvent('ws.error', fields: {'connectionId': connection.id}),
        error,
        stackTrace,
      ),
    );
  }

  void _onFrame(WsConnection connection, Object? frame) {
    final WsEnvelope envelope;
    try {
      if (frame is! String) {
        throw const FormatException('Only text frames are accepted.');
      }
      envelope = WsEnvelope.decode(frame);
    } on FormatException catch (e) {
      _log.fine(
        LogEvent(
          'ws.invalid_message',
          fields: {'connectionId': connection.id, 'reason': e.message},
          userContent: frame is String ? frame : null,
        ),
      );
      _sendError(connection, WsErrorCode.invalidMessage, e.message);
      return;
    }

    _log.fine(
      LogEvent(
        'ws.message',
        fields: {
          'connectionId': connection.id,
          'type': envelope.type,
          'id': envelope.id,
        },
      ),
    );
    switch (envelope.type) {
      case WsMessageType.runSubscribe:
        _handleRunSubscribe(connection, envelope);
      case WsMessageType.runUnsubscribe:
        _handleRunUnsubscribe(connection, envelope);
      default:
        _sendError(
          connection,
          WsErrorCode.unknownMessageType,
          'Unknown message type "${envelope.type}".',
          replyTo: envelope.id,
        );
    }
  }

  void _handleRunSubscribe(WsConnection connection, WsEnvelope envelope) {
    final RunSubscribePayload payload;
    try {
      payload = RunSubscribePayload.fromJson(envelope.payload);
      if (payload.runId.trim().isEmpty) {
        throw const FormatException('Field "runId" must not be blank.');
      }
    } on FormatException catch (e) {
      _sendError(
        connection,
        WsErrorCode.invalidMessage,
        e.message,
        replyTo: envelope.id,
      );
      return;
    }
    _registry.subscribeToRun(connection.id, payload.runId);
  }

  void _handleRunUnsubscribe(WsConnection connection, WsEnvelope envelope) {
    final RunUnsubscribePayload payload;
    try {
      payload = RunUnsubscribePayload.fromJson(envelope.payload);
      if (payload.runId.trim().isEmpty) {
        throw const FormatException('Field "runId" must not be blank.');
      }
    } on FormatException catch (e) {
      _sendError(
        connection,
        WsErrorCode.invalidMessage,
        e.message,
        replyTo: envelope.id,
      );
      return;
    }
    _registry.unsubscribeFromRun(connection.id, payload.runId);
  }

  void _sendError(
    WsConnection connection,
    String code,
    String message, {
    String? replyTo,
  }) => connection.send(
    WsEnvelope(
      type: WsMessageType.error,
      id: _generateId(),
      payload: WsErrorPayload(
        code: code,
        message: message,
        replyTo: replyTo,
      ).toJson(),
    ),
  );

  void _onDone(WsConnection connection) {
    _registry.remove(connection.id);
    _log.info(
      LogEvent(
        'ws.disconnected',
        fields: {
          'connectionId': connection.id,
          'closeCode': connection.channel.closeCode,
          'open': _registry.count,
        },
      ),
    );
  }
}
