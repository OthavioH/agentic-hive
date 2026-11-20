import 'dart:io';

import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/server/local_socket.dart';
import 'package:agentic_hive_backend/src/server/server_info_file.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Serves the API handler on the local Unix socket and publishes
/// `server.json` while it runs.
final class BackendServer {
  /// Creates a server that will serve [_handler] on [_socket].
  new({
    required this._handler,
    required this._socket,
    required this._serverInfo,
    required this._connections,
    required this._version,
  });

  static final _log = Logger('server');

  final Handler _handler;
  final LocalSocket _socket;
  final ServerInfoFile _serverInfo;
  final ConnectionRegistry _connections;
  final String _version;

  HttpServer? _server;

  /// Path of the Unix socket the server listens on.
  String get socketPath => _socket.path;

  /// Whether [start] succeeded and [stop] has not run yet.
  bool get isRunning => _server != null;

  /// Clears a stale socket, starts listening and writes `server.json`.
  ///
  /// Throws `BackendAlreadyRunningException` when another backend answers on
  /// the socket.
  Future<void> start({required DateTime startedAt}) async {
    if (_server != null) throw StateError('The server is already running.');
    await _socket.prepare();
    _server = await shelf_io.serve(
      _handler,
      _socket.address,
      0,
      poweredByHeader: null,
    );
    await _serverInfo.write(
      pid: pid,
      version: _version,
      socketPath: _socket.path,
      startedAt: startedAt,
    );
    _log.info(
      LogEvent(
        'server.started',
        fields: {'socketPath': _socket.path, 'pid': pid},
      ),
    );
  }

  /// Closes WebSockets first (they are hijacked, so the HTTP server does not
  /// track them), then the server, then removes the socket and `server.json`.
  ///
  /// Every step runs even if an earlier one fails, so a broken client never
  /// leaves the socket, `server.json`, the database or the logs open.
  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    try {
      await _connections.closeAll();
    } on Object catch (error, stackTrace) {
      _log.warning(
        const LogEvent('server.close_websockets_failed'),
        error,
        stackTrace,
      );
    } finally {
      await server.close(force: true);
      _socket.delete();
      await _serverInfo.delete();
      _log.info(const LogEvent('server.stopped'));
    }
  }
}
