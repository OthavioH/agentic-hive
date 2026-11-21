import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/di/dependencies.dart';
import 'package:agentic_hive_backend/src/server/backend_server.dart';
import 'package:agentic_hive_backend/src/server/local_socket.dart';
import 'package:get_it/get_it.dart';

/// A running backend: the entry point for `bin/server.dart` and for
/// integration tests.
final class Backend {
  new _(this._di, this.config);

  final GetIt _di;
  final Completer<void> _stopped = Completer<void>();
  Future<void>? _stopping;

  /// The configuration the backend was started with.
  final AppConfig config;

  /// Path of the Unix socket the backend listens on.
  String get socketPath => config.socketPath;

  /// Completes when [stop] finishes, including when triggered via
  /// `POST /api/v1/shutdown`.
  Future<void> get done => _stopped.future;

  /// Prepares the data folder, wires dependencies and starts serving.
  ///
  /// Pass a fresh `GetIt.asNewInstance()` as [di] in tests.
  static Future<Backend> start({
    required AppConfig config,
    PlatformPaths? platformPaths,
    GetIt? di,
    IOSink? consoleOut,
  }) async {
    final paths = platformPaths ?? currentPlatformPaths();
    final container = di ?? GetIt.instance;
    final startedAt = DateTime.now();

    await Directory(config.dataDir).create(recursive: true);
    await paths.restrictToOwner(config.dataDir);
    await Directory(config.agentsDir).create(recursive: true);

    // Fail fast, before opening the database or touching the log files, when
    // the path is too long or another backend already serves this folder.
    await LocalSocket(
      config.socketPath,
      maxPathBytes: paths.maxSocketPathBytes,
    ).prepare();

    final backend = Backend._(container, config);
    try {
      await registerDependencies(
        container,
        config: config,
        platformPaths: paths,
        startedAt: startedAt,
        onShutdown: backend.stop,
        consoleOut: consoleOut,
      );
      await container<BackendServer>().start(startedAt: startedAt);
    } on Object {
      await container.reset();
      rethrow;
    }
    return backend;
  }

  /// Stops the server, closes WebSockets and the database, flushes logs.
  Future<void> stop() => _stopping ??= _performStop();

  Future<void> _performStop() async {
    try {
      await _di.reset();
    } finally {
      if (!_stopped.isCompleted) _stopped.complete();
    }
  }
}
