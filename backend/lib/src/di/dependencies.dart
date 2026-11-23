import 'dart:io';

import 'package:agentic_hive_backend/src/api/agents/agents_handler.dart';
import 'package:agentic_hive_backend/src/api/harnesses/harnesses_handler.dart';
import 'package:agentic_hive_backend/src/api/overview/overview_handler.dart';
import 'package:agentic_hive_backend/src/api/pauses/pauses_handler.dart';
import 'package:agentic_hive_backend/src/api/result_contract/result_contract_handler.dart';
import 'package:agentic_hive_backend/src/api/runs/runs_handler.dart';
import 'package:agentic_hive_backend/src/api/settings/execution_settings_handler.dart';
import 'package:agentic_hive_backend/src/api/settings/settings_handler.dart';
import 'package:agentic_hive_backend/src/api/workflows/workflow_handler.dart';
import 'package:agentic_hive_backend/src/api/workspace/workspace_handler.dart';
import 'package:agentic_hive_backend/src/api/workspace/workspaces_handler.dart';
import 'package:agentic_hive_backend/src/api/worktrees/worktrees_handler.dart';
import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_directory_watcher.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/agents/local_workspace_agent_repositories.dart';
import 'package:agentic_hive_backend/src/data/agents/repository_agent_prompt_resolver.dart';
import 'package:agentic_hive_backend/src/data/agents/workspace_agent_watchers.dart';
import 'package:agentic_hive_backend/src/data/harnesses/antigravity_mcp_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/claude_code_mcp_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/codex_mcp_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/gemini_cli_mcp_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/harnesses/os_executable_locator.dart';
import 'package:agentic_hive_backend/src/data/nodes/dart_process_runner.dart';
import 'package:agentic_hive_backend/src/data/nodes/os_process_platform.dart';
import 'package:agentic_hive_backend/src/data/nodes/os_shell_provider.dart';
import 'package:agentic_hive_backend/src/data/nodes/pty_runner_factory.dart';
import 'package:agentic_hive_backend/src/data/overview/repository_overview_repository.dart';
import 'package:agentic_hive_backend/src/data/pauses/drift_pause_repository.dart';
import 'package:agentic_hive_backend/src/data/result_contract/hive_result_contract.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/file_run_log_store.dart';
import 'package:agentic_hive_backend/src/data/runs/process_tree_killer_factory.dart';
import 'package:agentic_hive_backend/src/data/settings/drift_settings_repository.dart';
import 'package:agentic_hive_backend/src/data/settings/file_workspace_settings_store.dart';
import 'package:agentic_hive_backend/src/data/settings/os_executable_validator.dart';
import 'package:agentic_hive_backend/src/data/workflows/drift_workflow_repository.dart';
import 'package:agentic_hive_backend/src/data/workflows/file_workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/data/workflows/workspace_workflow_watcher.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_snapshot_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_workspace_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/data/worktrees/run_repository_active_run_lookup.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/db/database_health_check.dart';
import 'package:agentic_hive_backend/src/db/metadata_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_service.dart';
import 'package:agentic_hive_backend/src/domain/agents/workspace_agent_repositories.dart';
import 'package:agentic_hive_backend/src/domain/engine/graph_engine.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/executable_locator.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/nodes/pty_session.dart';
import 'package:agentic_hive_backend/src/domain/overview/overview_repository.dart';
import 'package:agentic_hive_backend/src/domain/overview/overview_service.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_service.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_coordinator.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_validator.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/pausing_human_approval_port.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_recovery_service.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/settings/executable_validator.dart';
import 'package:agentic_hive_backend/src/domain/settings/execution_settings_service.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_repository.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_service.dart';
import 'package:agentic_hive_backend/src/domain/settings/workspace_settings_store.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/shadow_snapshot_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/snapshot_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_events.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/active_run_lookup.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/worktree_service.dart';
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
import 'package:agentic_hive_backend/src/ws/ws_workspace_events.dart';
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
    ..registerSingleton<HiveMcpLocator>(
      HiveMcpLocator(pathContext: platformPaths.context),
    )
    ..registerSingleton<HarnessMcpInstallerRegistry>(
      HarnessMcpInstallerRegistry([
        ClaudeCodeMcpInstaller(processRunner: di<ProcessRunner>()),
        CodexMcpInstaller(
          processRunner: di<ProcessRunner>(),
          pathContext: platformPaths.context,
        ),
        GeminiCliMcpInstaller(processRunner: di<ProcessRunner>()),
        AntigravityMcpInstaller(processRunner: di<ProcessRunner>()),
      ]),
    )
    ..registerSingleton<HarnessService>(
      DefaultHarnessService(
        detectors: di<List<HarnessDetector>>(),
        mcpInstallers: di<HarnessMcpInstallerRegistry>(),
        mcpLocator: di<HiveMcpLocator>(),
      ),
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
    ..registerSingleton<ManagedProcessTreeKiller>(currentProcessTreeKiller())
    ..registerSingleton<ProcessTreeKiller>(
      di<ManagedProcessTreeKiller>().killer,
    )
    ..registerSingleton<ProcessTreeTracker>(
      di<ManagedProcessTreeKiller>().tracker,
    )
    ..registerSingleton<NodeProcessRunner>(
      DartProcessRunner(
        platform: di<OsProcessPlatform>(),
        processTracker: di<ProcessTreeTracker>(),
      ),
    )
    ..registerSingleton<PtySessionRegistry>(
      PtySessionRegistry(),
      dispose: (registry) => registry.dispose(),
    )
    ..registerSingleton<PtyRunner>(
      currentPtyRunner(
        processTracker: di<ProcessTreeTracker>(),
        processTreeKiller: di<ProcessTreeKiller>(),
        sessionRegistry: di<PtySessionRegistry>(),
      ),
    )
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
    ..registerSingleton<HumanApprovalPort>(const PausingHumanApprovalPort())
    ..registerSingleton<LocalAgentRepository>(
      LocalAgentRepository(
        agentsDir: config.agentsDir,
        pathContext: platformPaths.context,
      ),
    )
    ..registerSingleton<AgentRepository>(di<LocalAgentRepository>())
    ..registerSingleton<WorkspaceAgentRepositories>(
      LocalWorkspaceAgentRepositories(
        findWorkspace: (id) => di<WorkspaceService>().get(id),
        pathContext: platformPaths.context,
      ),
    )
    ..registerSingleton<AgentPromptResolver>(
      RepositoryAgentPromptResolver(
        di<AgentRepository>(),
        workspaceAgents: di<WorkspaceAgentRepositories>().forRoot,
      ),
    )
    ..registerSingleton<NodeRegistry>(
      NodeRegistry.withDefaults(
        processRunner: di<NodeProcessRunner>(),
        ptyRunner: di<PtyRunner>(),
        defaultShellProvider: di<DefaultShellProvider>(),
        resultContract: di<ResultContract>(),
        approvalPort: di<HumanApprovalPort>(),
        agentPromptResolver: di<AgentPromptResolver>(),
        processTreeKiller: di<ProcessTreeKiller>(),
      ),
    )
    ..registerSingleton<WorkflowValidator>(
      WorkflowValidator(nodeRegistry: di<NodeRegistry>()),
    )
    ..registerSingletonWithDependencies<WorkspaceRepository>(
      () => DriftWorkspaceRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingleton<WorkspaceWorkflowRepository>(
      FileWorkspaceWorkflowRepository(pathContext: platformPaths.context),
    )
    ..registerSingletonWithDependencies<WorkflowService>(
      () => WorkflowService(
        repository: di<WorkflowRepository>(),
        validator: di<WorkflowValidator>(),
        workspaceWorkflows: di<WorkspaceWorkflowRepository>(),
        workspaces: di<WorkspaceRepository>(),
      ),
      dependsOn: [WorkflowRepository, WorkspaceRepository],
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
    ..registerSingletonWithDependencies<DriftRunEventRepository>(
      () => DriftRunEventRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
      dispose: (repo) => repo.close(),
    )
    ..registerSingletonWithDependencies<RunEventRepository>(
      () => di<DriftRunEventRepository>(),
      dependsOn: [DriftRunEventRepository],
    )
    ..registerSingletonWithDependencies<DriftPauseRepository>(
      () => DriftPauseRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
      dispose: (repo) => repo.close(),
    )
    ..registerSingletonWithDependencies<PauseRepository>(
      () => di<DriftPauseRepository>(),
      dependsOn: [DriftPauseRepository],
    )
    ..registerSingleton<RunLogStore>(
      FileRunLogStore(
        runsDir: config.runsDir,
        pathContext: platformPaths.context,
      ),
      dispose: (store) => store.close(),
    )
    ..registerSingleton<GitClient>(GitClient(di<ProcessRunner>()))
    ..registerSingleton<WorkspaceCapabilitiesService>(
      WorkspaceCapabilitiesService(di<GitClient>()),
    )
    ..registerSingletonWithDependencies<WorkspaceService>(
      () => WorkspaceService(
        workspaces: di<WorkspaceRepository>(),
        capabilities: di<WorkspaceCapabilitiesService>(),
        pathContext: platformPaths.context,
      ),
      dependsOn: [WorkspaceRepository],
    )
    ..registerSingletonWithDependencies<WorkspaceWorkflowWatcher>(
      () => WorkspaceWorkflowWatcher(
        workspaces: di<WorkspaceRepository>(),
        repository: di<WorkspaceWorkflowRepository>(),
        validator: di<WorkflowValidator>(),
        registry: di<ConnectionRegistry>(),
        pathContext: platformPaths.context,
      ),
      dependsOn: [WorkspaceRepository],
      dispose: (watcher) => watcher.close(),
    )
    ..registerSingletonWithDependencies<WorkspacesHandler>(
      () => WorkspacesHandler(
        service: di<WorkspaceService>(),
        onChanged: () => di<WorkspaceAgentWatchers>().sync(),
        events: di<WorkspaceEvents>(),
      ),
      dependsOn: [WorkspaceService],
    )
    ..registerSingletonWithDependencies<SettingsRepository>(
      () => DriftSettingsRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingleton<WorkspaceSettingsStore>(
      FileWorkspaceSettingsStore(pathContext: platformPaths.context),
    )
    ..registerSingletonWithDependencies<ExecutionSettingsService>(
      () => DefaultExecutionSettingsService(
        settings: di<SettingsRepository>(),
        workspaces: di<WorkspaceRepository>(),
        store: di<WorkspaceSettingsStore>(),
        shellProvider: di<DefaultShellProvider>(),
      ),
      dependsOn: [SettingsRepository, WorkspaceRepository],
    )
    ..registerSingletonWithDependencies<ExecutionSettingsHandler>(
      () => ExecutionSettingsHandler(di<ExecutionSettingsService>()),
      dependsOn: [ExecutionSettingsService],
    )
    ..registerSingletonWithDependencies<ActiveRunLookup>(
      () => RunRepositoryActiveRunLookup(di<RunRepository>()),
      dependsOn: [RunRepository],
    )
    ..registerSingletonWithDependencies<WorktreeService>(
      () => WorktreeService(
        git: di<GitClient>(),
        activeRuns: di<ActiveRunLookup>(),
        worktreesDir: config.worktreesDir,
        pathContext: platformPaths.context,
      ),
      dependsOn: [ActiveRunLookup],
    )
    ..registerSingletonWithDependencies<WorktreesHandler>(
      () => WorktreesHandler(
        workspaces: di<WorkspaceService>(),
        worktrees: di<WorktreeService>(),
        events: di<WorkspaceEvents>(),
      ),
      dependsOn: [WorkspaceService, WorktreeService],
    )
    ..registerSingletonWithDependencies<SnapshotRepository>(
      () => DriftSnapshotRepository(di<AppDatabase>()),
      dependsOn: [AppDatabase],
    )
    ..registerSingletonWithDependencies<WorkspacePreparationService>(
      () => WorkspacePreparationService(git: di<GitClient>()),
      dependsOn: [SnapshotRepository],
    )
    ..registerSingletonWithDependencies<ShadowSnapshotService>(
      () => ShadowSnapshotService(
        git: di<GitClient>(),
        runs: di<RunRepository>(),
        snapshots: di<SnapshotRepository>(),
        events: di<RunEventRepository>(),
        snapshotsDir: config.snapshotsDir,
        pathContext: platformPaths.context,
      ),
      dependsOn: [RunRepository, SnapshotRepository, RunEventRepository],
    )
    ..registerSingletonWithDependencies<WorkspaceHandler>(
      () => WorkspaceHandler(
        capabilities: di<WorkspaceCapabilitiesService>(),
        snapshots: di<ShadowSnapshotService>(),
      ),
      dependsOn: [ShadowSnapshotService],
    )
    ..registerSingletonWithDependencies<RunRecoveryService>(
      () => RunRecoveryService(
        runs: di<RunRepository>(),
        checkpoints: di<CheckpointRepository>(),
      ),
      dependsOn: [RunRepository, CheckpointRepository],
    )
    ..registerSingletonWithDependencies<GraphEngine>(
      () => GraphEngine(
        registry: di<NodeRegistry>(),
        runs: di<RunRepository>(),
        checkpoints: di<CheckpointRepository>(),
        events: di<RunEventRepository>(),
        recovery: di<RunRecoveryService>(),
        snapshots: di<ShadowSnapshotService>(),
        pauseGateway: di<HumanPauseGateway>(),
        processTreeKiller: di<ProcessTreeKiller>(),
        pauses: di<PauseRepository>(),
        logStore: di<RunLogStore>(),
      ),
      dependsOn: [
        RunRepository,
        CheckpointRepository,
        RunEventRepository,
        RunRecoveryService,
        ShadowSnapshotService,
        PauseRepository,
      ],
    )
    ..registerSingletonWithDependencies<RunService>(
      () => RunService(
        runs: di<RunRepository>(),
        checkpoints: di<CheckpointRepository>(),
        events: di<RunEventRepository>(),
        snapshots: di<ShadowSnapshotService>(),
        workspacePreparation: di<WorkspacePreparationService>(),
        workflows: di<WorkflowRepository>(),
        workspaceWorkflows: di<WorkspaceWorkflowRepository>(),
        workflowValidator: di<WorkflowValidator>(),
        workspaces: di<WorkspaceService>(),
        worktrees: di<WorktreeService>(),
        executionSettings: di<ExecutionSettingsService>(),
        engine: di<GraphEngine>(),
        logStore: di<RunLogStore>(),
        pathContext: platformPaths.context,
      ),
      dependsOn: [
        RunRepository,
        CheckpointRepository,
        RunEventRepository,
        ShadowSnapshotService,
        WorkspacePreparationService,
        WorkflowRepository,
        WorkspaceService,
        WorktreeService,
        ExecutionSettingsService,
        GraphEngine,
      ],
      dispose: (service) => service.dispose(),
    )
    ..registerSingletonWithDependencies<RunsHandler>(
      () => RunsHandler(service: di<RunService>()),
      dependsOn: [RunService],
    )
    ..registerSingletonWithDependencies<PauseService>(
      () => PauseService(
        pauses: di<PauseRepository>(),
        pauseGateway: di<HumanPauseGateway>(),
        resumePausedRun: di<RunService>().resumePausedRun,
      ),
      dependsOn: [PauseRepository, RunService],
    )
    ..registerSingletonWithDependencies<PausesHandler>(
      () => PausesHandler(service: di<PauseService>()),
      dependsOn: [PauseService],
    )
    ..registerSingletonWithDependencies<OverviewRepository>(
      () => RepositoryOverviewRepository(
        runs: di<RunRepository>(),
        events: di<RunEventRepository>(),
        pauses: di<PauseRepository>(),
        agents: di<AgentRepository>(),
      ),
      dependsOn: [RunRepository, RunEventRepository, PauseRepository],
    )
    ..registerSingletonWithDependencies<OverviewService>(
      () => OverviewService(di<OverviewRepository>()),
      dependsOn: [OverviewRepository],
    )
    ..registerSingletonWithDependencies<OverviewHandler>(
      () => OverviewHandler(service: di<OverviewService>()),
      dependsOn: [OverviewService],
    )
    ..registerSingleton<ConnectionRegistry>(ConnectionRegistry())
    ..registerSingleton<WorkspaceEvents>(
      WsWorkspaceEvents(di<ConnectionRegistry>()),
    )
    ..registerSingleton<AgentService>(
      AgentService(
        di<AgentRepository>(),
        workspaces: di<WorkspaceAgentRepositories>(),
        onWorkspaceAgentsChanged: () => di<WorkspaceAgentWatchers>().sync(),
      ),
    )
    ..registerSingleton<AgentsHandler>(AgentsHandler(di<AgentService>()))
    ..registerSingletonWithDependencies<WorkspaceAgentWatchers>(
      () => WorkspaceAgentWatchers(
        listWorkspaces: () => di<WorkspaceService>().list(),
        repositoryFor: di<WorkspaceAgentRepositories>().forRoot,
        registry: di<ConnectionRegistry>(),
        pathContext: platformPaths.context,
      ),
      dependsOn: [WorkspaceService],
      dispose: (watchers) => watchers.close(),
    )
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
    ..registerSingleton<ExecutableValidator>(currentExecutableValidator())
    ..registerSingletonWithDependencies<SettingsService>(
      () => DefaultSettingsService(
        repository: di<SettingsRepository>(),
        config: config,
        executableValidator: di<ExecutableValidator>(),
        agentRepository: di<LocalAgentRepository>(),
        agentDirectoryWatcher: di<AgentDirectoryWatcher>(),
        harnessService: di<HarnessService>(),
        pathContext: platformPaths.context,
      ),
      dependsOn: [SettingsRepository, AgentDirectoryWatcher],
      dispose: (service) => service.dispose(),
    )
    ..registerSingletonWithDependencies<SettingsHandler>(
      () => SettingsHandler(di<SettingsService>()),
      dependsOn: [SettingsService],
    )
    ..registerSingletonWithDependencies<WsGateway>(
      () => WsGateway(
        registry: di<ConnectionRegistry>(),
        pingInterval: config.webSocketPingInterval,
        serverVersion: backendVersion,
        harnessStatusUpdates: di<HarnessService>().statusUpdates,
        settingsUpdates: di<SettingsService>().settingsUpdates,
        runEvents: di<DriftRunEventRepository>().events,
        runOutputs: di<RunLogStore>().outputs,
        ptySessions: di<PtySessionRegistry>(),
        pauseCreated: di<DriftPauseRepository>().created,
        pauseResolved: di<DriftPauseRepository>().resolved,
      ),
      dependsOn: [
        SettingsService,
        DriftRunEventRepository,
        DriftPauseRepository,
      ],
      dispose: (gateway) => gateway.close(),
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
          pausesHandler: di<PausesHandler>(),
          overviewHandler: di<OverviewHandler>(),
          workspaceHandler: di<WorkspaceHandler>(),
          workspacesHandler: di<WorkspacesHandler>(),
          worktreesHandler: di<WorktreesHandler>(),
          settingsHandler: di<SettingsHandler>(),
          executionSettingsHandler: di<ExecutionSettingsHandler>(),
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
        PausesHandler,
        OverviewHandler,
        WorkspaceHandler,
        WorkspacesHandler,
        WorktreesHandler,
        SettingsHandler,
        ExecutionSettingsHandler,
        WsGateway,
      ],
      dispose: (server) => server.stop(),
    );

  await di.allReady();
  await di<WorkspaceAgentWatchers>().sync();
  await di<WorkspaceWorkflowWatcher>().start();
}
