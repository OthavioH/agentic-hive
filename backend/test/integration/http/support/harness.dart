import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Upper bound for any single wait in these tests.
const ioTimeout = Duration(seconds: 10);

/// Creates a short, fresh temporary folder that is deleted after the test.
///
/// The prefix is kept short because the socket path inside it is limited to
/// 103 to 107 bytes depending on the operating system.
Future<Directory> createTempDir() async {
  final dir = await Directory.systemTemp.createTemp('ah');
  addTearDown(() => deleteWithRetry(dir));
  return dir;
}

/// Deletes [dir], retrying briefly while Windows still holds a handle.
Future<void> deleteWithRetry(Directory dir) async {
  for (var attempt = 0; ; attempt++) {
    if (!dir.existsSync()) return;
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt >= 20) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

/// An [IOSink] that discards everything written to it.
IOSink discardingSink() => IOSink(_DiscardConsumer());

final class _DiscardConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<void> close() async {}
}

/// The development configuration rooted at [dataDir].
AppConfig configFor(String dataDir) =>
    AppConfig(mode: RuntimeMode.development, dataDir: dataDir);

/// Starts the real backend on [dataDir] with an isolated container.
///
/// The backend is stopped after the test unless [stopOnTearDown] is false.
Future<Backend> startBackend(
  String dataDir, {
  bool stopOnTearDown = true,
}) async {
  final backend = await Backend.start(
    config: configFor(dataDir),
    di: GetIt.asNewInstance(),
    consoleOut: discardingSink(),
  ).timeout(ioTimeout);
  if (stopOnTearDown) addTearDown(() => backend.stop().timeout(ioTimeout));
  return backend;
}

/// A decoded HTTP response received over the Unix socket.
final class SocketResponse {
  /// Creates a response record.
  const new(this.statusCode, this.headers, this.body);

  /// The HTTP status code.
  final int statusCode;

  /// The response headers.
  final HttpHeaders headers;

  /// The raw body.
  final String body;

  /// The body decoded as a JSON object.
  JsonMap get json => jsonDecode(body) as JsonMap;
}

/// An HTTP client that connects to the backend's Unix socket, the way the
/// frontend does (ADR 0011).
final class SocketHttpClient {
  /// Creates a client for the socket at [socketPath].
  new(String socketPath) : _client = _socketClient(socketPath);

  final HttpClient _client;

  static HttpClient _socketClient(String socketPath) {
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    return HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) =>
          Socket.startConnect(address, 0);
  }

  /// Sends `GET` to [pathAndQuery] with optional extra [headers].
  Future<SocketResponse> get(
    String pathAndQuery, {
    Map<String, String> headers = const {},
  }) => _send('GET', pathAndQuery, headers: headers);

  /// Sends `DELETE` to [pathAndQuery] with optional extra [headers].
  Future<SocketResponse> delete(
    String pathAndQuery, {
    Map<String, String> headers = const {},
  }) => _send('DELETE', pathAndQuery, headers: headers);

  Future<SocketResponse> _send(
    String method,
    String pathAndQuery, {
    Map<String, String> headers = const {},
  }) async {
    final request = await _client
        .openUrl(method, Uri.parse('http://localhost$pathAndQuery'))
        .timeout(ioTimeout);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(ioTimeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(ioTimeout);
    return SocketResponse(response.statusCode, response.headers, body);
  }

  /// Closes the client and its idle connections.
  void close() => _client.close(force: true);
}

/// Opens a [SocketHttpClient] on [socketPath], closed after the test.
SocketHttpClient openClient(String socketPath) {
  final client = SocketHttpClient(socketPath);
  addTearDown(client.close);
  return client;
}

/// Path of `server.json` inside [dataDir].
String serverInfoPathIn(String dataDir) => p.join(dataDir, 'server.json');

/// Path of the socket file inside [dataDir].
String socketPathIn(String dataDir) => p.join(dataDir, 'backend.sock');

/// Whether anything (socket or regular file) exists at [path].
bool entityExists(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) !=
    FileSystemEntityType.notFound;
