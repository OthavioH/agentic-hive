import 'dart:async';

import 'package:agentic_hive_backend/src/domain/nodes/pty_session.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One open WebSocket connection.
final class WsConnection {
  /// Wraps [channel] under a unique [id].
  new({required this.id, required this.channel});

  /// Unique id of the connection, used in logs.
  final String id;

  /// The underlying channel.
  final WebSocketChannel channel;

  /// Sends [envelope] as a text frame.
  void send(WsEnvelope envelope) => channel.sink.add(envelope.encode());
}

/// The open WebSocket connections, for broadcasting and shutdown.
final class ConnectionRegistry {
  final _connections = <String, WsConnection>{};
  final _runSubscriptions = <String, Set<String>>{};
  final _ptySubscriptions = <PtySessionKey, Set<String>>{};

  /// Number of open connections.
  int get count => _connections.length;

  /// The open connections.
  Iterable<WsConnection> get connections => _connections.values;

  /// Tracks [connection] until [remove] or [closeAll].
  void add(WsConnection connection) => _connections[connection.id] = connection;

  /// Stops tracking the connection with [connectionId] and clears its run
  /// subscriptions.
  void remove(String connectionId) {
    _connections.remove(connectionId);
    for (final subscribers in _runSubscriptions.values) {
      subscribers.remove(connectionId);
    }
    _runSubscriptions.removeWhere((_, subscribers) => subscribers.isEmpty);
    for (final subscribers in _ptySubscriptions.values) {
      subscribers.remove(connectionId);
    }
    _ptySubscriptions.removeWhere((_, subscribers) => subscribers.isEmpty);
  }

  /// Subscribes [connectionId] to `run.output` frames for [runId].
  void subscribeToRun(String connectionId, String runId) {
    if (!_connections.containsKey(connectionId)) return;
    (_runSubscriptions[runId] ??= <String>{}).add(connectionId);
  }

  /// Unsubscribes [connectionId] from `run.output` frames for [runId].
  void unsubscribeFromRun(String connectionId, String runId) {
    final subscribers = _runSubscriptions[runId];
    if (subscribers == null) return;
    subscribers.remove(connectionId);
    if (subscribers.isEmpty) {
      _runSubscriptions.remove(runId);
    }
  }

  /// Whether [connectionId] is currently subscribed to [runId].
  bool isSubscribedToRun(String connectionId, String runId) =>
      _runSubscriptions[runId]?.contains(connectionId) ?? false;

  /// Subscribes [connectionId] to `pty.output` frames for [key].
  void subscribeToPty(String connectionId, PtySessionKey key) {
    if (!_connections.containsKey(connectionId)) return;
    (_ptySubscriptions[key] ??= <String>{}).add(connectionId);
  }

  /// Unsubscribes [connectionId] from `pty.output` frames for [key].
  void unsubscribeFromPty(String connectionId, PtySessionKey key) {
    final subscribers = _ptySubscriptions[key];
    if (subscribers == null) return;
    subscribers.remove(connectionId);
    if (subscribers.isEmpty) {
      _ptySubscriptions.remove(key);
    }
  }

  /// Whether [connectionId] is currently subscribed to PTY session [key].
  bool isSubscribedToPty(String connectionId, PtySessionKey key) =>
      _ptySubscriptions[key]?.contains(connectionId) ?? false;

  /// Sends [envelope] to every open connection.
  void broadcast(WsEnvelope envelope) {
    final frame = envelope.encode();
    for (final connection in _connections.values) {
      connection.channel.sink.add(frame);
    }
  }

  /// Sends [envelope] only to open connections subscribed to [runId].
  void broadcastToRun(String runId, WsEnvelope envelope) {
    final subscribers = _runSubscriptions[runId];
    if (subscribers == null || subscribers.isEmpty) return;
    final frame = envelope.encode();
    for (final connectionId in subscribers) {
      _connections[connectionId]?.channel.sink.add(frame);
    }
  }

  /// Sends [envelope] only to open connections subscribed to PTY session [key].
  void broadcastToPty(PtySessionKey key, WsEnvelope envelope) {
    final subscribers = _ptySubscriptions[key];
    if (subscribers == null || subscribers.isEmpty) return;
    final frame = envelope.encode();
    for (final connectionId in subscribers) {
      _connections[connectionId]?.channel.sink.add(frame);
    }
  }

  /// Closes every connection with [WsCloseCode.serverShuttingDown].
  ///
  /// The registry is emptied before closing, because a close can remove its
  /// connection from the registry while this method runs.
  Future<void> closeAll() async {
    final open = _connections.values.toList();
    _connections.clear();
    _runSubscriptions.clear();
    _ptySubscriptions.clear();
    await Future.wait([
      for (final connection in open)
        connection.channel.sink.close(
          WsCloseCode.serverShuttingDown,
          'Server shutting down',
        ),
    ]);
  }
}
