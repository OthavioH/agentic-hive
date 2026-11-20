import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Upper bound for every wait in this suite. Waits end as soon as their
/// condition holds; this only turns a hang into a failure.
const waitTimeout = Duration(seconds: 5);

/// Creates a fresh, short temporary folder (Unix socket paths are limited to
/// about 104 bytes).
Future<Directory> createShortTempDir() =>
    Directory.systemTemp.createTemp('ahws');

/// Deletes [dir], ignoring a folder that is already gone.
Future<void> deleteDir(Directory dir) async {
  if (dir.existsSync()) await dir.delete(recursive: true);
}

/// A real backend started on a fresh data folder for one test.
///
/// It tracks the clients it connects and its log events, so [dispose] can
/// close every client and wait until the server has removed each one before
/// stopping.
final class TestBackend {
  new _(this.backend, this.dataDir, this.logs);

  /// Starts a development backend on a fresh temporary data folder.
  static Future<TestBackend> start() async {
    final logs = LogEvents();
    final dir = await createShortTempDir();
    final backend = await Backend.start(
      config: AppConfig(mode: RuntimeMode.development, dataDir: dir.path),
      di: GetIt.asNewInstance(),
      consoleOut: IOSink(_DiscardingConsumer()),
    );
    return TestBackend._(backend, dir, logs);
  }

  /// The running backend.
  final Backend backend;

  /// Its data folder.
  final Directory dataDir;

  /// The backend's log events since before it started.
  final LogEvents logs;

  final _clients = <WsTestClient>[];
  bool _stopped = false;

  /// Path of the backend's Unix socket.
  String get socketPath => backend.socketPath;

  /// Today's (UTC) JSON-lines log file.
  File get todayLogFile {
    final now = DateTime.now().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final day = '${now.year}-${two(now.month)}-${two(now.day)}';
    return File(p.join(dataDir.path, 'logs', 'backend-$day.jsonl'));
  }

  /// Connects a tracked client; [dispose] closes it.
  Future<WsTestClient> connect({Map<String, Object>? headers}) async {
    final client = await WsTestClient.connect(socketPath, headers: headers);
    _clients.add(client);
    return client;
  }

  /// Closes every tracked client and waits until the server logged a
  /// `ws.disconnected` for every `ws.connected`.
  Future<void> closeClients() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    await logs.waitUntil(
      () =>
          logs.named('ws.disconnected').length >=
          logs.named('ws.connected').length,
    );
  }

  /// Stops the backend once; later calls do nothing.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await backend.stop().timeout(waitTimeout);
  }

  /// Closes the clients, stops the backend and deletes its data folder.
  Future<void> dispose() async {
    try {
      if (!_stopped) await closeClients();
      await stop();
    } finally {
      await logs.dispose();
      await deleteDir(dataDir);
    }
  }
}

/// Swallows everything written to it.
final class _DiscardingConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<void> close() async {}
}

/// Builds an [HttpClient] whose every connection goes to the Unix socket at
/// [socketPath].
HttpClient unixSocketHttpClient(String socketPath) => HttpClient()
  ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(
    InternetAddress(socketPath, type: InternetAddressType.unix),
    0,
  );

/// A real `dart:io` WebSocket client that records every frame it receives,
/// in order, and hands them out one at a time.
final class WsTestClient {
  new _(this._socket, this._httpClient) {
    _socket.listen(_onFrame, onDone: _onDone, onError: _onError);
  }

  /// Connects to `ws://localhost/ws` over the Unix socket at [socketPath].
  static Future<WsTestClient> connect(
    String socketPath, {
    Map<String, Object>? headers,
  }) async {
    final httpClient = unixSocketHttpClient(socketPath);
    try {
      final socket = await WebSocket.connect(
        'ws://localhost/ws',
        headers: headers,
        customClient: httpClient,
      ).timeout(waitTimeout);
      return WsTestClient._(socket, httpClient);
    } on Object {
      httpClient.close(force: true);
      rethrow;
    }
  }

  final WebSocket _socket;
  final HttpClient _httpClient;
  final _unread = Queue<Object?>();
  final _done = Completer<void>();
  Completer<void>? _arrival;

  /// Every frame received so far, in arrival order (decoded when text).
  final received = <Object?>[];

  /// Close code sent by the server, once [done] completed.
  int? get closeCode => _socket.closeCode;

  /// Close reason sent by the server, once [done] completed.
  String? get closeReason => _socket.closeReason;

  /// Completes when the server side closed the connection.
  Future<void> get done => _done.future;

  /// Whether the connection has closed.
  bool get isClosed => _done.isCompleted;

  void _onFrame(Object? frame) {
    received.add(frame);
    _unread.add(frame);
    _wake();
  }

  void _onError(Object error) {
    received.add(error);
    _wake();
  }

  void _onDone() {
    if (!_done.isCompleted) _done.complete();
    _wake();
  }

  void _wake() {
    final arrival = _arrival;
    _arrival = null;
    arrival?.complete();
  }

  Future<Object?> _nextFrame() async {
    while (_unread.isEmpty) {
      if (isClosed) {
        throw StateError(
          'Connection closed ($closeCode) before the next message arrived.',
        );
      }
      await (_arrival ??= Completer<void>()).future;
    }
    return _unread.removeFirst();
  }

  /// The next unread message, decoded as an envelope.
  Future<WsEnvelope> next({Duration timeout = waitTimeout}) async {
    final frame = await _nextFrame().timeout(timeout);
    if (frame is! String) {
      throw StateError('Expected a text frame, got ${frame.runtimeType}.');
    }
    return WsEnvelope.decode(frame);
  }

  /// Sends a raw text frame.
  void sendText(String text) => _socket.add(text);

  /// Sends a raw binary frame.
  void sendBinary(List<int> bytes) => _socket.add(bytes);

  /// Sends [envelope] as a text frame.
  void sendEnvelope(WsEnvelope envelope) => sendText(envelope.encode());

  /// Waits until the server closes the connection.
  Future<void> waitClosed({Duration timeout = waitTimeout}) =>
      done.timeout(timeout);

  /// Closes the connection from the client side (normal closure) and waits
  /// for the server to confirm.
  Future<void> close([int code = WebSocketStatus.normalClosure]) async {
    if (!isClosed) {
      await _socket.close(code).timeout(waitTimeout);
    }
    _httpClient.close(force: true);
  }
}

/// Decodes the payload of an `error` envelope, checking its type first.
WsErrorPayload errorPayloadOf(WsEnvelope envelope) {
  if (envelope.type != WsMessageType.error) {
    throw StateError('Expected an error message, got "${envelope.type}".');
  }
  return WsErrorPayload.fromJson(envelope.payload);
}

/// Collects the backend's [LogEvent] records while attached, and lets a test
/// wait for one without polling.
final class LogEvents {
  /// Starts listening to the root logger.
  new() {
    _subscription = Logger.root.onRecord.listen(_onRecord);
  }

  late final StreamSubscription<LogRecord> _subscription;
  final _events = StreamController<LogEvent>.broadcast(sync: true);

  /// Every [LogEvent] seen so far, in order.
  final events = <LogEvent>[];

  void _onRecord(LogRecord record) {
    final object = record.object;
    if (object is! LogEvent) return;
    events.add(object);
    _events.add(object);
  }

  /// Events named [name] seen so far.
  Iterable<LogEvent> named(String name) => events.where((e) => e.name == name);

  /// The first event (already seen or future) named [name] whose fields
  /// satisfy [where].
  Future<LogEvent> waitFor(
    String name, {
    bool Function(Map<String, Object?> fields)? where,
    Duration timeout = waitTimeout,
  }) {
    bool matches(LogEvent e) =>
        e.name == name && (where?.call(e.fields) ?? true);
    for (final event in events) {
      if (matches(event)) return Future.value(event);
    }
    return _events.stream.firstWhere(matches).timeout(timeout);
  }

  /// Completes once [condition] holds, checking it now and after every new
  /// event.
  Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = waitTimeout,
  }) async {
    if (condition()) return;
    await _events.stream.firstWhere((_) => condition()).timeout(timeout);
  }

  /// Stops listening.
  Future<void> dispose() async {
    await _subscription.cancel();
    await _events.close();
  }
}

/// Reads the JSON lines of [file] as objects.
List<JsonMap> readJsonLines(File file) => [
  for (final line in file.readAsLinesSync())
    if (line.trim().isNotEmpty) jsonDecode(line) as JsonMap,
];
