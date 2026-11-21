import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [BackendWebSocketSession] backed by a `dart:io` [WebSocket].
final class SocketBackendWebSocketSession implements BackendWebSocketSession {
  new _({required this._socket, required this.serverHello, this._onClosed});

  /// Validates the initial `server.hello` frame on [socket] within
  /// [handshakeTimeout] and returns a live [SocketBackendWebSocketSession].
  static Future<Result<BackendWebSocketSession>> connect(
    WebSocket socket, {
    required Duration handshakeTimeout,
    void Function()? onClosed,
  }) async {
    final handshakeCompleter = Completer<Result<ServerHelloPayload>>();
    SocketBackendWebSocketSession? session;
    late final StreamSubscription<dynamic> subscription;

    void failHandshake(Failure failure) {
      if (!handshakeCompleter.isCompleted) {
        handshakeCompleter.complete(FailureResult(failure));
      }
      unawaited(subscription.cancel());
      unawaited(socket.close());
      onClosed?.call();
    }

    subscription = socket.listen(
      (dynamic frame) {
        if (!handshakeCompleter.isCompleted) {
          final parsed = _parseServerHello(frame);
          if (parsed case FailureResult<ServerHelloPayload>(:final failure)) {
            failHandshake(failure);
            return;
          }
          final hello = (parsed as Success<ServerHelloPayload>).value;
          if (hello.protocolVersion != wsProtocolVersion) {
            failHandshake(
              BackendFailure(
                'Incompatible WebSocket protocol version '
                '${hello.protocolVersion} (expected $wsProtocolVersion).',
                code: BackendFailureCode.protocolMismatch,
              ),
            );
            return;
          }
          session = SocketBackendWebSocketSession._(
            socket: socket,
            serverHello: hello,
            onClosed: onClosed,
          );
          handshakeCompleter.complete(Success(hello));
          return;
        }

        final activeSession = session;
        if (activeSession == null || activeSession._isClosed) return;
        activeSession._handlePostHandshakeFrame(frame);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!handshakeCompleter.isCompleted) {
          failHandshake(
            NetworkFailure(
              'WebSocket error before server.hello handshake.',
              cause: error,
            ),
          );
          return;
        }
        session?._handleStreamError(error, stackTrace);
      },
      onDone: () {
        if (!handshakeCompleter.isCompleted) {
          failHandshake(
            const NetworkFailure(
              'WebSocket closed before server.hello handshake.',
            ),
          );
          return;
        }
        session?._handleDone();
      },
    );

    try {
      final result = await handshakeCompleter.future.timeout(handshakeTimeout);
      if (result case FailureResult<ServerHelloPayload>(:final failure)) {
        return FailureResult(failure);
      }
      return Success(session!);
    } on TimeoutException catch (error) {
      failHandshake(
        NetworkFailure(
          'Timed out waiting for server.hello handshake.',
          cause: error,
          code: BackendFailureCode.timeout,
        ),
      );
      return FailureResult(
        NetworkFailure(
          'Timed out waiting for server.hello handshake.',
          cause: error,
          code: BackendFailureCode.timeout,
        ),
      );
    }
  }

  static Result<ServerHelloPayload> _parseServerHello(dynamic frame) {
    if (frame is! String) {
      return const FailureResult(
        BackendFailure('Expected text frame for server.hello handshake.'),
      );
    }
    try {
      final envelope = WsEnvelope.decode(frame);
      if (envelope.type != WsMessageType.serverHello) {
        return FailureResult(
          BackendFailure(
            'Expected "${WsMessageType.serverHello}" as first frame, '
            'got "${envelope.type}".',
          ),
        );
      }
      return Success(ServerHelloPayload.fromJson(envelope.payload));
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Invalid server.hello frame: ${error.message}'),
      );
    }
  }

  final WebSocket _socket;
  final void Function()? _onClosed;
  final StreamController<WsEnvelope> _messagesController =
      StreamController<WsEnvelope>.broadcast();
  final Completer<void> _doneCompleter = Completer<void>();

  bool _isClosed = false;

  @override
  final ServerHelloPayload serverHello;

  @override
  Stream<WsEnvelope> get messages => _messagesController.stream;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  bool get isClosed => _isClosed;

  @override
  Future<Result<void>> send(WsEnvelope envelope) async {
    if (_isClosed) {
      return const FailureResult(
        NetworkFailure('Cannot send on a closed WebSocket session.'),
      );
    }
    try {
      _socket.add(envelope.encode());
      return const Success(null);
    } on SocketException catch (error) {
      return FailureResult(
        NetworkFailure(
          'Socket error while sending WebSocket frame.',
          cause: error,
          code: BackendFailureCode.connectionRefused,
        ),
      );
    } on Object catch (error) {
      return FailureResult(
        NetworkFailure('Failed to send WebSocket frame.', cause: error),
      );
    }
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_isClosed) return;
    _markClosed();
    try {
      await _socket.close(code, reason);
    } on Object {
      // Best-effort close on an already broken socket.
    }
  }

  void _handlePostHandshakeFrame(dynamic frame) {
    if (frame is! String) {
      _messagesController.addError(
        const FormatException('Only text WebSocket frames are supported.'),
      );
      return;
    }
    try {
      _messagesController.add(WsEnvelope.decode(frame));
    } on FormatException catch (error) {
      _messagesController.addError(error);
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_isClosed) return;
    _messagesController.addError(error, stackTrace);
    _markClosed();
  }

  void _handleDone() {
    _markClosed();
  }

  void _markClosed() {
    if (_isClosed) return;
    _isClosed = true;
    if (!_messagesController.isClosed) {
      unawaited(_messagesController.close());
    }
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    _onClosed?.call();
  }
}
