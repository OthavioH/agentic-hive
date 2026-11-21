import 'dart:io';

import 'package:agentic_hive_backend/src/api/agents/agents_handler.dart';
import 'package:agentic_hive_backend/src/api/harnesses/harnesses_handler.dart';
import 'package:agentic_hive_backend/src/api/result_contract/result_contract_handler.dart';
import 'package:agentic_hive_backend/src/api/runs/runs_handler.dart';
import 'package:agentic_hive_backend/src/api/workflows/workflow_handler.dart';
import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_directory_watcher.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/harnesses/os_executable_locator.dart';
import 'package:agentic_hive_backend/src/data/nodes/dart_process_runner.dart';
import 'package:agentic_hive_backend/src/data/nodes/os_process_platform.dart';
import 'package:agentic_hive_backend/src/data/nodes/os_shell_provider.dart';
import 'package:agentic_hive_backend/src/data/nodes/unconfigured_node_ports.dart';
import 'package:agentic_hive_backend/src/data/result_contract/hive_result_contract.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/data/workflows/drift_workflow_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/db/database_health_check.dart';
import 'package:agentic_hive_backend/src/db/metadata_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/executable_locator.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_coordinator.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_validator.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_recovery_service.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/logging/log_formatter.dart';
import 'package:agentic_hive_backend/src/logging/log_sink.dart';
import 'package:agentic_hive_backend/src/logging/logging_setup.dart';
import 'package:agentic_hive_backend/src/logging/redactor.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_backend/src/server/backend_server.dart';
import 'package:agentic_hive_backend/src/server/local_socket.dart';
import 'package:agentic_hive_backend/src/server/server_info_file.dart';
import 'package:agentic_hive_backend/src/version.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_backend/src/ws/ws_gateway.dart';
import 'package:get_it/get_it.dart';

Future<void> _noOpShutdown() async {}

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
  Future<void> Function()? onShutdown,
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
    ..registerSingleton<ProcessRunner>(const IoProcessRunner())
    ..registerSingleton<ExecutableLocator>(
      currentExecutableLocator(di<ProcessRunner>()),
    )
    ..registerSingleton<List<HarnessDetector>>([
      ClaudeCodeDetector(
        executableLocator: di<ExecutableLocator>(),
        processRunner: di<ProcessRunner>(),
      ),
      CodexDetector(
        executableLocator: di<ExecutableLocator>(),
        processRunner: di<ProcessRunner>(),
      ),
      GeminiCliDetector(
        executableLocator: di<ExecutableLocator>(),
        processRunner: di<ProcessRunner>(),
      ),
      AntigravityDetector(
        executableLocator: di<ExecutableLocator>(),
        processRunner: di<ProcessRunner>(),
      ),
    ])
    ..registerSingleton<HarnessService>(
      DefaultHarnessService(detectors: di<List<HarnessDetector>>()),
      dispose: (service) => service.dispose(),
    )
    ..registerSingleton<HarnessesHandler>(
      HarnessesHandler(harnessService: di<HarnessService>()),
    )
    ..registerSingletonWithDependencies<WorkflowRepository>(
      () => DriftWorkflowRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingleton<OsProcessPlatform>(currentProcessPlatform())
    ..registerSingleton<DefaultShellProvider>(currentDefaultShellProvider())
    ..registerSingleton<NodeProcessRunner>(
      DartProcessRunner(platform: di<OsProcessPlatform>()),
    )
    ..registerSingleton<PtyRunner>(const UnconfiguredPtyRunner())
    ..registerSingleton<ResultContractValidator>(
      ResultContractValidator(pathContext: platformPaths.context),
    )
    ..registerSingleton<ResultContractCoordinator>(
      ResultContractCoordinator(validator: di<ResultContractValidator>()),
    )
    ..registerSingleton<HumanPauseGateway>(
      InMemoryHumanPauseGateway(),
      dispose: (gateway) {
        if (gateway is InMemoryHumanPauseGateway) {
          gateway.dispose();
        }
      },
    )
    ..registerSingleton<HiveMcpLocator>(
      HiveMcpLocator(pathContext: platformPaths.context),
    )
    ..registerSingleton<ResultContract>(
      HiveResultContract(
        coordinator: di<ResultContractCoordinator>(),
        dataDir: config.dataDir,
        socketPath: config.socketPath,
        mcpLocator: di<HiveMcpLocator>(),
        humanPauseGateway: di<HumanPauseGateway>(),
        validator: di<ResultContractValidator>(),
        pathContext: platformPaths.context,
      ),
    )
    ..registerSingleton<ResultContractHandler>(
      ResultContractHandler(
        coordinator: di<ResultContractCoordinator>(),
        humanPauseGateway: di<HumanPauseGateway>(),
      ),
    )
    ..registerSingleton<HumanApprovalPort>(
      const UnconfiguredHumanApprovalPort(),
    )
    ..registerSingleton<AgentPromptResolver>(
      const UnconfiguredAgentPromptResolver(),
    )
    ..registerSingleton<NodeRegistry>(
      NodeRegistry.withDefaults(
        processRunner: di<NodeProcessRunner>(),
        ptyRunner: di<PtyRunner>(),
        defaultShellProvider: di<DefaultShellProvider>(),
        resultContract: di<ResultContract>(),
        approvalPort: di<HumanApprovalPort>(),
        agentPromptResolver: di<AgentPromptResolver>(),
      ),
    )
    ..registerSingleton<WorkflowValidator>(
      WorkflowValidator(nodeRegistry: di<NodeRegistry>()),
    )
    ..registerSingletonWithDependencies<WorkflowService>(
      () => WorkflowService(
        repository: di<WorkflowRepository>(),
        validator: di<WorkflowValidator>(),
      ),
      dependsOn: [WorkflowRepository],
    )
    ..registerSingletonWithDependencies<WorkflowHandler>(
      () => WorkflowHandler(service: di<WorkflowService>()),
      dependsOn: [WorkflowService],
    )
    ..registerSingletonWithDependencies<RunRepository>(
      () => DriftRunRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingletonWithDependencies<CheckpointRepository>(
      () => DriftCheckpointRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingletonWithDependencies<RunEventRepository>(
      () => DriftRunEventRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingletonWithDependencies<RunRecoveryService>(
      () => RunRecoveryService(
        runs: di<RunRepository>(),
        checkpoints: di<CheckpointRepository>(),
      ),
      dependsOn: [RunRepository, CheckpointRepository],
    )
    ..registerSingletonWithDependencies<RunService>(
      () => RunService(
        runs: di<RunRepository>(),
        checkpoints: di<CheckpointRepository>(),
        events: di<RunEventRepository>(),
      ),
      dependsOn: [RunRepository, CheckpointRepository, RunEventRepository],
    )
    ..registerSingletonWithDependencies<RunsHandler>(
      () => RunsHandler(service: di<RunService>()),
      dependsOn: [RunService],
    )
    ..registerSingleton<ConnectionRegistry>(ConnectionRegistry())
    ..registerSingleton<WsGateway>(
      WsGateway(
        registry: di<ConnectionRegistry>(),
        pingInterval: config.webSocketPingInterval,
        serverVersion: backendVersion,
        harnessStatusUpdates: di<HarnessService>().statusUpdates,
      ),
      dispose: (gateway) => gateway.close(),
    )
    ..registerSingleton<AgentRepository>(
      LocalAgentRepository(
        agentsDir: config.agentsDir,
        pathContext: platformPaths.context,
      ),
    )
    ..registerSingleton<AgentService>(AgentService(di<AgentRepository>()))
    ..registerSingleton<AgentsHandler>(AgentsHandler(di<AgentService>()))
    ..registerSingletonAsync<AgentDirectoryWatcher>(() async {
      final watcher = AgentDirectoryWatcher(
        agentsDir: config.agentsDir,
        repository: di<AgentRepository>(),
        registry: di<ConnectionRegistry>(),
        pathContext: platformPaths.context,
      );
      await watcher.start();
      return watcher;
    }, dispose: (watcher) => watcher.close())
    ..registerSingletonWithDependencies<StatusHandler>(
      () => StatusHandler(
        databaseHealthCheck: di<DatabaseHealthCheck>(),
        version: backendVersion,
        dataDir: config.dataDir,
        startedAt: startedAt,
      ),
      dependsOn: [DatabaseHealthCheck],
    )
    ..registerSingleton<ShutdownHandler>(
      ShutdownHandler(onShutdown: onShutdown ?? _noOpShutdown),
    )
    ..registerSingletonWithDependencies<BackendServer>(
      () => BackendServer(
        handler: buildApiHandler(
          statusHandler: di<StatusHandler>(),
          shutdownHandler: di<ShutdownHandler>(),
          webSocketHandler: di<WsGateway>().handler,
          agentsHandler: di<AgentsHandler>(),
          harnessesHandler: di<HarnessesHandler>(),
          workflowHandler: di<WorkflowHandler>(),
          resultContractHandler: di<ResultContractHandler>(),
          runsHandler: di<RunsHandler>(),
        ),
        socket: LocalSocket(
          config.socketPath,
          maxPathBytes: platformPaths.maxSocketPathBytes,
        ),
        serverInfo: ServerInfoFile(config.serverInfoPath),
        connections: di<ConnectionRegistry>(),
        version: backendVersion,
      ),
      dependsOn: [
        StatusHandler,
        AgentDirectoryWatcher,
        WorkflowHandler,
        RunsHandler,
      ],
      dispose: (server) => server.stop(),
    );

  await di.allReady();
}
