import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/pty_session.dart';
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
    PtySessionRegistry? ptySessions,
    Stream<Pause>? pauseCreated,
    Stream<Pause>? pauseResolved,
    this._generateId = randomId,
  }) : _ptySessions = ptySessions {
    _harnessUpdatesSubscription = harnessStatusUpdates?.listen(
      _broadcastHarnessStatus,
    );
    _settingsUpdatesSubscription = settingsUpdates?.listen(
      _broadcastSettingsUpdated,
    );
    _runEventsSubscription = runEvents?.listen(_broadcastRunEvent);
    _runOutputsSubscription = runOutputs?.listen(_broadcastRunOutput);
    _ptyOutputsSubscription = ptySessions?.outputs.listen(_broadcastPtyOutput);
    _ptyEndedSubscription = ptySessions?.sessionEnded.listen(
      _registry.removePtySubscribers,
    );
    _pauseCreatedSubscription = pauseCreated?.listen(_broadcastPauseCreated);
    _pauseResolvedSubscription = pauseResolved?.listen(_broadcastPauseResolved);
  }

  static final _log = Logger('ws');

  /// Maximum decoded byte length accepted in a single `pty.input` frame.
  static const int maxPtyInputBytes = 64 * 1024;

  /// Maximum terminal dimensions accepted in `pty.resize`.
  static const int maxPtyDimension = 1000;

  final ConnectionRegistry _registry;
  final Duration _pingInterval;
  final String _serverVersion;
  final PtySessionRegistry? _ptySessions;
  final String Function() _generateId;
  StreamSubscription<HarnessInfo>? _harnessUpdatesSubscription;
  StreamSubscription<AppSettings>? _settingsUpdatesSubscription;
  StreamSubscription<RunEvent>? _runEventsSubscription;
  StreamSubscription<RunOutputPayload>? _runOutputsSubscription;
  StreamSubscription<PtyOutputPayload>? _ptyOutputsSubscription;
  StreamSubscription<PtySessionKey>? _ptyEndedSubscription;
  StreamSubscription<Pause>? _pauseCreatedSubscription;
  StreamSubscription<Pause>? _pauseResolvedSubscription;

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
    await _ptyOutputsSubscription?.cancel();
    _ptyOutputsSubscription = null;
    await _ptyEndedSubscription?.cancel();
    _ptyEndedSubscription = null;
    await _pauseCreatedSubscription?.cancel();
    _pauseCreatedSubscription = null;
    await _pauseResolvedSubscription?.cancel();
    _pauseResolvedSubscription = null;
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

  void _broadcastPtyOutput(PtyOutputPayload output) {
    _registry.broadcastToPty(
      (runId: output.runId, nodeId: output.nodeId, attempt: output.attempt),
      WsEnvelope(
        type: WsMessageType.ptyOutput,
        id: _generateId(),
        payload: output.toJson(),
      ),
    );
  }

  void _broadcastPauseCreated(Pause pause) {
    _registry.broadcast(
      WsEnvelope(
        type: WsMessageType.pauseCreated,
        id: _generateId(),
        payload: PauseCreatedPayload(pause: pause).toJson(),
      ),
    );
  }

  void _broadcastPauseResolved(Pause pause) {
    _registry.broadcast(
      WsEnvelope(
        type: WsMessageType.pauseResolved,
        id: _generateId(),
        payload: PauseResolvedPayload(pause: pause).toJson(),
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
      case WsMessageType.ptySubscribe:
        _handlePtySubscribe(connection, envelope);
      case WsMessageType.ptyUnsubscribe:
        _handlePtyUnsubscribe(connection, envelope);
      case WsMessageType.ptyInput:
        unawaited(_handlePtyInput(connection, envelope));
      case WsMessageType.ptyResize:
        unawaited(_handlePtyResize(connection, envelope));
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

  PtySessionKey? _validatePtyTarget(
    WsConnection connection,
    WsEnvelope envelope, {
    required String runId,
    required String nodeId,
    required int attempt,
  }) {
    if (runId.trim().isEmpty) {
      _sendError(
        connection,
        WsErrorCode.invalidMessage,
        'Field "runId" must not be blank.',
        replyTo: envelope.id,
      );
      return null;
    }
    if (nodeId.trim().isEmpty) {
      _sendError(
        connection,
        WsErrorCode.invalidMessage,
        'Field "nodeId" must not be blank.',
        replyTo: envelope.id,
      );
      return null;
    }
    if (attempt < 1) {
      _sendError(
        connection,
        WsErrorCode.invalidMessage,
        'Field "attempt" must be >= 1.',
        replyTo: envelope.id,
      );
      return null;
    }
    return (runId: runId, nodeId: nodeId, attempt: attempt);
  }

  void _handlePtySubscribe(WsConnection connection, WsEnvelope envelope) {
    final PtySubscribePayload payload;
    try {
      payload = PtySubscribePayload.fromJson(envelope.payload);
    } on FormatException catch (e) {
      _sendError(
        connection,
        WsErrorCode.invalidMessage,
        e.message,
        replyTo: envelope.id,
      );
      return;
    }
    final key = _validatePtyTarget(
      connection,
      envelope,
      runId: payload.runId,
      nodeId: payload.nodeId,
      attempt: payload.attempt,
    );
    if (key == null) return;

    // Flush pending coalesced output and take the snapshot *before*
    // subscribing so the new subscriber does not receive both the snapshot
    // and the pending chunk in the same coalesce window.
    final snapshot = _ptySessions?.getScrollbackSnapshot(key);
    if (snapshot == null) {
      _sendError(
        connection,
        WsErrorCode.ptySessionNotActive,
        'PTY session is not active or has already ended.',
        replyTo: envelope.id,
      );
      return;
    }

    _registry.subscribeToPty(connection.id, key);
    if (snapshot.isNotEmpty) {
      connection.send(
        WsEnvelope(
          type: WsMessageType.ptyOutput,
          id: _generateId(),
          payload: PtyOutputPayload(
            runId: key.runId,
            nodeId: key.nodeId,
            attempt: key.attempt,
            data: base64Encode(snapshot),
            timestamp: DateTime.now().toUtc(),
            isSnapshot: true,
          ).toJson(),
        ),
      );
    }
  }

  void _handlePtyUnsubscribe(WsConnection connection, WsEnvelope envelope) {
    final PtyUnsubscribePayload payload;
    try {
      payload = PtyUnsubscribePayload.fromJson(envelope.payload);
    } on FormatException catch (e) {
      _sendError(
        connection,
        WsErrorCode.invalidMessage,
        e.message,
        replyTo: envelope.id,
      );
      return;
    }
    final key = _validatePtyTarget(
      connection,
      envelope,
      runId: payload.runId,
      nodeId: payload.nodeId,
      attempt: payload.attempt,
    );
    if (key == null) return;
    _registry.unsubscribeFromPty(connection.id, key);
  }

  Future<void> _handlePtyInput(
    WsConnection connection,
    WsEnvelope envelope,
  ) async {
    final PtyInputPayload payload;
    final List<int> bytes;
    try {
      payload = PtyInputPayload.fromJson(envelope.payload);
      if (payload.data.length > (maxPtyInputBytes * 4 ~/ 3) + 4) {
        throw const FormatException(
          'Field "data" exceeds maximum PTY input size (64 KiB).',
        );
      }
      bytes = base64Decode(payload.data);
      if (bytes.length > maxPtyInputBytes) {
        throw const FormatException(
          'Decoded PTY input exceeds maximum size (64 KiB).',
        );
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
    final key = _validatePtyTarget(
      connection,
      envelope,
      runId: payload.runId,
      nodeId: payload.nodeId,
      attempt: payload.attempt,
    );
    if (key == null) return;

    final sessions = _ptySessions;
    if (sessions == null) {
      _sendError(
        connection,
        WsErrorCode.ptySessionNotActive,
        'PTY session is not active.',
        replyTo: envelope.id,
      );
      return;
    }
    final result = await sessions.writeInput(key, bytes);
    if (result case FailureResult<void>(:final failure)) {
      _sendError(
        connection,
        WsErrorCode.ptySessionNotActive,
        failure.message,
        replyTo: envelope.id,
      );
    }
  }

  Future<void> _handlePtyResize(
    WsConnection connection,
    WsEnvelope envelope,
  ) async {
    final PtyResizePayload payload;
    try {
      payload = PtyResizePayload.fromJson(envelope.payload);
      if (payload.cols <= 0 || payload.rows <= 0) {
        throw const FormatException('Fields "cols" and "rows" must be > 0.');
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
    final key = _validatePtyTarget(
      connection,
      envelope,
      runId: payload.runId,
      nodeId: payload.nodeId,
      attempt: payload.attempt,
    );
    if (key == null) return;

    final sessions = _ptySessions;
    if (sessions == null) {
      _sendError(
        connection,
        WsErrorCode.ptySessionNotActive,
        'PTY session is not active.',
        replyTo: envelope.id,
      );
      return;
    }
    final result = await sessions.resize(
      key,
      cols: payload.cols.clamp(1, maxPtyDimension),
      rows: payload.rows.clamp(1, maxPtyDimension),
    );
    if (result case FailureResult<void>(:final failure)) {
      _sendError(
        connection,
        WsErrorCode.ptySessionNotActive,
        failure.message,
        replyTo: envelope.id,
      );
    }
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
