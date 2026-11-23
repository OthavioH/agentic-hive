import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory [WebSocketChannel] whose outgoing frames can be observed.
final class FakeWebSocketChannel implements WebSocketChannel {
  final _incoming = StreamController<Object?>.broadcast();
  final _outgoing = StreamController<Object?>.broadcast();

  Stream<Object?> get outgoing => _outgoing.stream;

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => FakeWebSocketSink(_outgoing);

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class FakeWebSocketSink implements WebSocketSink {
  new(this._controller);

  final StreamController<Object?> _controller;

  @override
  void add(Object? data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Object?> stream) =>
      _controller.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) =>
      _controller.close();

  @override
  Future<void> get done => _controller.done;
}
