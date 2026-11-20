import 'dart:async';

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

  /// Number of open connections.
  int get count => _connections.length;

  /// The open connections.
  Iterable<WsConnection> get connections => _connections.values;

  /// Tracks [connection] until [remove] or [closeAll].
  void add(WsConnection connection) => _connections[connection.id] = connection;

  /// Stops tracking the connection with [connectionId].
  void remove(String connectionId) => _connections.remove(connectionId);

  /// Sends [envelope] to every open connection.
  void broadcast(WsEnvelope envelope) {
    final frame = envelope.encode();
    for (final connection in _connections.values) {
      connection.channel.sink.add(frame);
    }
  }

  /// Closes every connection with [WsCloseCode.serverShuttingDown].
  ///
  /// The registry is emptied before closing, because a close can remove its
  /// connection from the registry while this method runs.
  Future<void> closeAll() async {
    final open = _connections.values.toList();
    _connections.clear();
    await Future.wait([
      for (final connection in open)
        connection.channel.sink.close(
          WsCloseCode.serverShuttingDown,
          'Server shutting down',
        ),
    ]);
  }
}
