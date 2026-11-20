import 'dart:io';

import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/db/database_health_check.dart';
import 'package:agentic_hive_backend/src/db/metadata_repository.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/logging/log_formatter.dart';
import 'package:agentic_hive_backend/src/logging/log_sink.dart';
import 'package:agentic_hive_backend/src/logging/logging_setup.dart';
import 'package:agentic_hive_backend/src/logging/redactor.dart';
import 'package:agentic_hive_backend/src/server/backend_server.dart';
import 'package:agentic_hive_backend/src/server/local_socket.dart';
import 'package:agentic_hive_backend/src/server/server_info_file.dart';
import 'package:agentic_hive_backend/src/version.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_backend/src/ws/ws_gateway.dart';
import 'package:get_it/get_it.dart';

/// Registers every backend dependency in [di].
///
/// The single place that wires implementations to interfaces. Classes receive
/// their dependencies through constructors and never call `GetIt` themselves.
/// Tests pass `GetIt.asNewInstance()` and may push a scope that shadows any
/// registration.
///
/// `di.reset()` disposes in reverse order: server and WebSockets first,
/// then the database, then logging.
Future<void> registerDependencies(
  GetIt di, {
  required AppConfig config,
  required PlatformPaths platformPaths,
  required DateTime startedAt,
  IOSink? consoleOut,
}) async {
  di
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<PlatformPaths>(platformPaths)
    ..registerSingleton<Redactor>(Redactor())
    ..registerSingleton<LogFormatter>(LogFormatter(di<Redactor>()))
    ..registerSingleton<LoggingSetup>(
      LoggingSetup(
        level: config.logLevel,
        sinks: [
          ConsoleLogSink(di<LogFormatter>(), out: consoleOut),
          RotatingFileLogSink(
            di<LogFormatter>(),
            directory: config.logsDir,
            retentionDays: config.logRetentionDays,
          ),
        ],
      ),
      dispose: (logging) => logging.close(),
    )
    ..registerSingletonAsync<AppDatabase>(() async {
      final db = AppDatabase.open(File(config.databasePath));
      await db.customSelect('SELECT 1').get();
      return db;
    }, dispose: (db) => db.close())
    ..registerSingletonWithDependencies<MetadataRepository>(
      () => DriftMetadataRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingletonWithDependencies<DatabaseHealthCheck>(
      () => DriftDatabaseHealthCheck(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingleton<ConnectionRegistry>(ConnectionRegistry())
    ..registerSingleton<WsGateway>(
      WsGateway(
        registry: di<ConnectionRegistry>(),
        pingInterval: config.webSocketPingInterval,
        serverVersion: backendVersion,
      ),
    )
    ..registerSingletonWithDependencies<StatusHandler>(
      () => StatusHandler(
        databaseHealthCheck: di<DatabaseHealthCheck>(),
        version: backendVersion,
        dataDir: config.dataDir,
        startedAt: startedAt,
      ),
      dependsOn: [DatabaseHealthCheck],
    )
    ..registerSingletonWithDependencies<BackendServer>(
      () => BackendServer(
        handler: buildApiHandler(
          statusHandler: di<StatusHandler>(),
          webSocketHandler: di<WsGateway>().handler,
        ),
        socket: LocalSocket(
          config.socketPath,
          maxPathBytes: platformPaths.maxSocketPathBytes,
        ),
        serverInfo: ServerInfoFile(config.serverInfoPath),
        connections: di<ConnectionRegistry>(),
        version: backendVersion,
      ),
      dependsOn: [StatusHandler],
      dispose: (server) => server.stop(),
    );

  await di.allReady();
}
