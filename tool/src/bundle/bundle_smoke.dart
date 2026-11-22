import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bundle_layout.dart';
import 'output_tail.dart';
import 'server_info.dart';
import 'smoke_result.dart';

/// Starts the bundled backend from [layout] with a temporary data folder and
/// checks it.
final class BundleSmoke {
  /// Creates a [BundleSmoke] runner for [layout].
  new({
    required this.layout,
    required this.log,
    this.startTimeout = const Duration(seconds: 30),
    this.requestTimeout = const Duration(seconds: 10),
    this.stopTimeout = const Duration(seconds: 15),
  });

  /// Layout of the bundle to test.
  final BundleLayout layout;

  /// Callback for progress log lines.
  final void Function(String line) log;

  /// Maximum time to wait for `server.json` to appear.
  final Duration startTimeout;

  /// Maximum time to wait for each HTTP request.
  final Duration requestTimeout;

  /// Maximum time to wait for the server to exit after shutdown.
  final Duration stopTimeout;

  /// Runs the smoke test and returns the [SmokeResult].
  Future<SmokeResult> run() async {
    final stopwatch = Stopwatch()..start();

    final missing = layout.missingFiles((path) => File(path).existsSync());
    if (missing.isNotEmpty) {
      return MissingFilesFailure(missing);
    }
    log('layout: ok (${layout.root})');

    final temp = Directory.systemTemp.createTempSync('hive_smoke_');
    final dataDir = p.join(temp.path, 'data');
    final configFile = File(p.join(temp.path, 'config.yaml'))
      ..writeAsStringSync('');
    final serverInfoPath = p.join(dataDir, 'server.json');

    SmokeResult? failure;
    void recordFailure(SmokeResult next) {
      failure ??= next;
    }

    Process? process;
    int? exited;
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;
    HttpClient? client;

    try {
      final tail = OutputTail();
      try {
        process = await Process.start(layout.serverPath, [
          '--data-dir',
          dataDir,
          '--config',
          configFile.path,
        ]);
      } on ProcessException catch (e) {
        return ServerLaunchFailure(layout.serverPath, e.message);
      }

      unawaited(process.exitCode.then((code) => exited = code));
      stdoutSub = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(tail.add);
      stderrSub = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(tail.add);

      final info = await _waitForServerInfo(
        serverInfoPath: serverInfoPath,
        stopwatch: stopwatch,
        exited: () => exited,
        tail: tail,
        onFailure: recordFailure,
      );
      if (info == null) {
        return failure!;
      }

      client = _createSocketClient(info.socketPath);
      final healthFailure = await _checkHealth(client);
      if (healthFailure != null) {
        recordFailure(healthFailure);
      }
    } finally {
      if (process != null) {
        final stopFailure = await _stopProcess(
          process: process,
          client: client,
          exited: () => exited,
        );
        if (stopFailure != null) {
          recordFailure(stopFailure);
        }
      }
      client?.close(force: true);
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      await _cleanupTempDir(temp);
    }

    return failure ?? SmokePassed(stopwatch.elapsed);
  }

  Future<ServerInfo?> _waitForServerInfo({
    required String serverInfoPath,
    required Stopwatch stopwatch,
    required int? Function() exited,
    required OutputTail tail,
    required void Function(SmokeResult) onFailure,
  }) async {
    final startWatch = Stopwatch()..start();
    while (!File(serverInfoPath).existsSync()) {
      final code = exited();
      if (code != null) {
        onFailure(ServerExitedFailure(code, tail.text));
        return null;
      }
      if (startWatch.elapsed > startTimeout) {
        onFailure(
          ServerInfoTimeoutFailure(serverInfoPath, startTimeout, tail.text),
        );
        return null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final secs = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
    log('start: server.json written after ${secs}s');

    try {
      final info = ServerInfo.parse(File(serverInfoPath).readAsStringSync());
      log('start: server pid ${info.pid}, socket ${info.socketPath}');
      return info;
    } on FormatException catch (e) {
      onFailure(InvalidServerInfoFailure(serverInfoPath, e.message));
      return null;
    }
  }

  HttpClient _createSocketClient(String socketPath) {
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    return HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) =>
          Socket.startConnect(address, 0);
  }

  Future<SmokeFailure?> _checkHealth(HttpClient client) async {
    try {
      final request = await client
          .getUrl(Uri.parse('http://localhost/health'))
          .timeout(requestTimeout);
      final response = await request.close().timeout(requestTimeout);
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        return HealthCheckFailure(response.statusCode, body);
      }
      log('health: GET /health -> 200 $body');
      return null;
    } on SocketException catch (e) {
      return HealthCheckFailure(null, '$e');
    } on HttpException catch (e) {
      return HealthCheckFailure(null, '$e');
    } on TimeoutException catch (e) {
      return HealthCheckFailure(null, '$e');
    }
  }

  Future<SmokeFailure?> _stopProcess({
    required Process process,
    required HttpClient? client,
    required int? Function() exited,
  }) async {
    if (exited() == null && client != null) {
      try {
        final request = await client
            .postUrl(Uri.parse('http://localhost/api/v1/shutdown'))
            .timeout(requestTimeout);
        request.headers.contentType = ContentType.json;
        request.write('{}');
        final response = await request.close().timeout(requestTimeout);
        await response.drain<void>().timeout(requestTimeout);
      } on SocketException {
        // Fallback below handles exit/kill.
      } on HttpException {
        // Fallback below handles exit/kill.
      } on TimeoutException {
        // Fallback below handles exit/kill.
      }
    }

    try {
      final code = await process.exitCode.timeout(stopTimeout);
      if (code != 0) {
        return StopFailure(
          'exited with code $code after POST /api/v1/shutdown',
        );
      }
      log('stop: server exited with code 0');
      return null;
    } on TimeoutException {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // Best-effort wait after kill.
      }
      return StopFailure(
        'no exit within ${stopTimeout.inSeconds}s after POST '
        '/api/v1/shutdown; killed',
      );
    }
  }

  Future<void> _cleanupTempDir(Directory temp) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        temp.deleteSync(recursive: true);
        return;
      } on FileSystemException catch (e) {
        if (attempt == 4) {
          stderr.writeln('warning: could not delete ${temp.path}: $e');
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }
}
