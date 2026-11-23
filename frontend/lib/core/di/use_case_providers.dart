// Entry point for Riverpod use case providers (ADR 0017).
//
// Feature use case providers are registered here so presentation controllers
// depend on domain use cases without importing data implementations.
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/overview/overview_providers.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/settings/file_picker_repository_impl.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_tree_changes_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/create_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/delete_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/dismiss_agents_migration_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/get_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/get_agents_migration_status_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/list_agents_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/update_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/watch_agent_changes_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/get_harnesses_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/install_harness_mcp_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/refresh_harness_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/refresh_harnesses_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/watch_harness_updates_use_case.dart';
import 'package:agentic_hive_frontend/domain/overview/use_cases/get_overview_use_case.dart';
import 'package:agentic_hive_frontend/domain/overview/use_cases/watch_overview_events_use_case.dart';
import 'package:agentic_hive_frontend/domain/pauses/use_cases/answer_pause_use_case.dart';
import 'package:agentic_hive_frontend/domain/pauses/use_cases/list_pending_pauses_use_case.dart';
import 'package:agentic_hive_frontend/domain/pauses/use_cases/watch_pause_events_use_case.dart';
import 'package:agentic_hive_frontend/domain/pauses/use_cases/watch_pending_pauses_count_use_case.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/cancel_run.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/delete_run.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/get_node_logs.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/get_run.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/get_run_checkpoints.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/get_run_events.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/list_runs.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/resize_pty.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/resume_run.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/send_pty_input.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/start_run.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/subscribe_pty.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/unsubscribe_pty.dart';
import 'package:agentic_hive_frontend/domain/settings/get_settings.dart';
import 'package:agentic_hive_frontend/domain/settings/pick_directory.dart';
import 'package:agentic_hive_frontend/domain/settings/pick_file.dart';
import 'package:agentic_hive_frontend/domain/settings/update_settings.dart';
import 'package:agentic_hive_frontend/domain/settings/watch_settings_updates.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/create_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/delete_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/duplicate_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/get_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/list_workflows.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/update_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/validate_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/watch_workflow_changes.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/create_workspace.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/get_snapshot_diff.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/get_workspace_capabilities.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/get_workspace_settings.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/list_run_snapshots.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/list_workspaces.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/list_worktrees.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/load_last_workspace_id.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/remove_worktree.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/rename_workspace.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/restore_snapshot.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/save_last_workspace_id.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/unregister_workspace.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/update_workspace_settings.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/watch_workspace_tree_changes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'use_case_providers.g.dart';

/// Provides [ListAgentsUseCase].
@riverpod
ListAgentsUseCase listAgentsUseCase(Ref ref) =>
    ListAgentsUseCase(ref.watch(agentRepositoryProvider));

/// Provides [GetAgentUseCase].
@riverpod
GetAgentUseCase getAgentUseCase(Ref ref) =>
    GetAgentUseCase(ref.watch(agentRepositoryProvider));

/// Provides [CreateAgentUseCase].
@riverpod
CreateAgentUseCase createAgentUseCase(Ref ref) =>
    CreateAgentUseCase(ref.watch(agentRepositoryProvider));

/// Provides [UpdateAgentUseCase].
@riverpod
UpdateAgentUseCase updateAgentUseCase(Ref ref) =>
    UpdateAgentUseCase(ref.watch(agentRepositoryProvider));

/// Provides [DeleteAgentUseCase].
@riverpod
DeleteAgentUseCase deleteAgentUseCase(Ref ref) =>
    DeleteAgentUseCase(ref.watch(agentRepositoryProvider));

/// Provides [WatchAgentChangesUseCase].
@riverpod
WatchAgentChangesUseCase watchAgentChangesUseCase(Ref ref) =>
    WatchAgentChangesUseCase(ref.watch(agentRepositoryProvider));

/// Provides [GetAgentsMigrationStatusUseCase].
@riverpod
GetAgentsMigrationStatusUseCase getAgentsMigrationStatusUseCase(Ref ref) =>
    GetAgentsMigrationStatusUseCase(
      ref.watch(agentsMigrationRepositoryProvider),
    );

/// Provides [DismissAgentsMigrationUseCase].
@riverpod
DismissAgentsMigrationUseCase dismissAgentsMigrationUseCase(Ref ref) =>
    DismissAgentsMigrationUseCase(ref.watch(agentsMigrationRepositoryProvider));

/// Provides [GetHarnessesUseCase].
@riverpod
GetHarnessesUseCase getHarnessesUseCase(Ref ref) =>
    GetHarnessesUseCase(ref.watch(harnessRepositoryProvider));

/// Provides [RefreshHarnessesUseCase].
@riverpod
RefreshHarnessesUseCase refreshHarnessesUseCase(Ref ref) =>
    RefreshHarnessesUseCase(ref.watch(harnessRepositoryProvider));

/// Provides [RefreshHarnessUseCase].
@riverpod
RefreshHarnessUseCase refreshHarnessUseCase(Ref ref) =>
    RefreshHarnessUseCase(ref.watch(harnessRepositoryProvider));

/// Provides [InstallHarnessMcpUseCase].
@riverpod
InstallHarnessMcpUseCase installHarnessMcpUseCase(Ref ref) =>
    InstallHarnessMcpUseCase(ref.watch(harnessRepositoryProvider));

/// Provides [WatchHarnessUpdatesUseCase].
@riverpod
WatchHarnessUpdatesUseCase watchHarnessUpdatesUseCase(Ref ref) =>
    WatchHarnessUpdatesUseCase(ref.watch(harnessRepositoryProvider));

/// Provides [ListWorkflows].
@riverpod
ListWorkflows listWorkflows(Ref ref) =>
    ListWorkflows(ref.watch(workflowRepositoryProvider));

/// Provides [GetWorkflow].
@riverpod
GetWorkflow getWorkflow(Ref ref) =>
    GetWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [CreateWorkflow].
@riverpod
CreateWorkflow createWorkflow(Ref ref) =>
    CreateWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [UpdateWorkflow].
@riverpod
UpdateWorkflow updateWorkflow(Ref ref) =>
    UpdateWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [DuplicateWorkflow].
@riverpod
DuplicateWorkflow duplicateWorkflow(Ref ref) =>
    DuplicateWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [DeleteWorkflow].
@riverpod
DeleteWorkflow deleteWorkflow(Ref ref) =>
    DeleteWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [WatchWorkflowChanges].
@riverpod
WatchWorkflowChanges watchWorkflowChanges(Ref ref) =>
    WatchWorkflowChanges(ref.watch(workflowChangesSourceProvider));

/// Provides [WatchWorkspaceTreeChanges].
@riverpod
WatchWorkspaceTreeChanges watchWorkspaceTreeChanges(Ref ref) =>
    WatchWorkspaceTreeChanges(ref.watch(workspaceTreeChangesSourceProvider));

/// Provides [ValidateWorkflow].
@riverpod
ValidateWorkflow validateWorkflow(Ref ref) =>
    ValidateWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [ListRuns].
@riverpod
ListRuns listRuns(Ref ref) => ListRuns(ref.watch(runRepositoryProvider));

/// Provides [GetRun].
@riverpod
GetRun getRun(Ref ref) => GetRun(ref.watch(runRepositoryProvider));

/// Provides [GetRunEvents].
@riverpod
GetRunEvents getRunEvents(Ref ref) =>
    GetRunEvents(ref.watch(runRepositoryProvider));

/// Provides [GetRunCheckpoints].
@riverpod
GetRunCheckpoints getRunCheckpoints(Ref ref) =>
    GetRunCheckpoints(ref.watch(runRepositoryProvider));

/// Provides [DeleteRun].
@riverpod
DeleteRun deleteRun(Ref ref) => DeleteRun(ref.watch(runRepositoryProvider));

/// Provides [StartRun].
@riverpod
StartRun startRun(Ref ref) => StartRun(ref.watch(runRepositoryProvider));

/// Provides [CancelRun].
@riverpod
CancelRun cancelRun(Ref ref) => CancelRun(ref.watch(runRepositoryProvider));

/// Provides [ResumeRun].
@riverpod
ResumeRun resumeRun(Ref ref) => ResumeRun(ref.watch(runRepositoryProvider));

/// Provides [GetNodeLogs].
@riverpod
GetNodeLogs getNodeLogs(Ref ref) =>
    GetNodeLogs(ref.watch(runRepositoryProvider));

/// Provides [SubscribePty].
@riverpod
SubscribePty subscribePty(Ref ref) =>
    SubscribePty(ref.watch(ptyRepositoryProvider));

/// Provides [UnsubscribePty].
@riverpod
UnsubscribePty unsubscribePty(Ref ref) =>
    UnsubscribePty(ref.watch(ptyRepositoryProvider));

/// Provides [SendPtyInput].
@riverpod
SendPtyInput sendPtyInput(Ref ref) =>
    SendPtyInput(ref.watch(ptyRepositoryProvider));

/// Provides [ResizePty].
@riverpod
ResizePty resizePty(Ref ref) => ResizePty(ref.watch(ptyRepositoryProvider));

/// Provides [GetWorkspaceCapabilities].
@riverpod
GetWorkspaceCapabilities getWorkspaceCapabilities(Ref ref) =>
    GetWorkspaceCapabilities(ref.watch(workspaceRepositoryProvider));

/// Provides [ListRunSnapshots].
@riverpod
ListRunSnapshots listRunSnapshots(Ref ref) =>
    ListRunSnapshots(ref.watch(workspaceRepositoryProvider));

/// Provides [GetSnapshotDiff].
@riverpod
GetSnapshotDiff getSnapshotDiff(Ref ref) =>
    GetSnapshotDiff(ref.watch(workspaceRepositoryProvider));

/// Provides [RestoreSnapshot].
@riverpod
RestoreSnapshot restoreSnapshot(Ref ref) =>
    RestoreSnapshot(ref.watch(workspaceRepositoryProvider));

/// Provides [GetSettings].
@riverpod
GetSettings getSettings(Ref ref) =>
    GetSettings(ref.watch(settingsRepositoryProvider));

/// Provides [UpdateSettings].
@riverpod
UpdateSettings updateSettings(Ref ref) =>
    UpdateSettings(ref.watch(settingsRepositoryProvider));

/// Provides [WatchSettingsUpdates].
@riverpod
WatchSettingsUpdates watchSettingsUpdates(Ref ref) =>
    WatchSettingsUpdates(ref.watch(settingsRepositoryProvider));

/// Provides [PickDirectory].
@riverpod
PickDirectory pickDirectory(Ref ref) =>
    PickDirectory(ref.watch(filePickerRepositoryProvider));

/// Provides [PickFile].
@riverpod
PickFile pickFile(Ref ref) => PickFile(ref.watch(filePickerRepositoryProvider));

/// Provides [ListPendingPausesUseCase].
@riverpod
ListPendingPausesUseCase listPendingPausesUseCase(Ref ref) =>
    ListPendingPausesUseCase(ref.watch(pauseRepositoryProvider));

/// Provides [AnswerPauseUseCase].
@riverpod
AnswerPauseUseCase answerPauseUseCase(Ref ref) =>
    AnswerPauseUseCase(ref.watch(pauseRepositoryProvider));

/// Provides [WatchPendingPausesCountUseCase].
@riverpod
WatchPendingPausesCountUseCase watchPendingPausesCountUseCase(Ref ref) =>
    WatchPendingPausesCountUseCase(ref.watch(pauseRepositoryProvider));

/// Provides [WatchPauseEventsUseCase].
@riverpod
WatchPauseEventsUseCase watchPauseEventsUseCase(Ref ref) =>
    WatchPauseEventsUseCase(ref.watch(pauseRepositoryProvider));

/// Provides [GetOverviewUseCase].
@riverpod
GetOverviewUseCase getOverviewUseCase(Ref ref) =>
    GetOverviewUseCase(ref.watch(overviewRepositoryProvider));

/// Provides [WatchOverviewEventsUseCase].
@riverpod
WatchOverviewEventsUseCase watchOverviewEventsUseCase(Ref ref) =>
    WatchOverviewEventsUseCase(ref.watch(overviewRepositoryProvider));

/// Provides [ListWorkspaces].
@riverpod
ListWorkspaces listWorkspaces(Ref ref) =>
    ListWorkspaces(ref.watch(workspaceRepositoryProvider));

/// Provides [CreateWorkspace].
@riverpod
CreateWorkspace createWorkspace(Ref ref) =>
    CreateWorkspace(ref.watch(workspaceRepositoryProvider));

/// Provides [RenameWorkspace].
@riverpod
RenameWorkspace renameWorkspace(Ref ref) =>
    RenameWorkspace(ref.watch(workspaceRepositoryProvider));

/// Provides [UnregisterWorkspace].
@riverpod
UnregisterWorkspace unregisterWorkspace(Ref ref) =>
    UnregisterWorkspace(ref.watch(workspaceRepositoryProvider));

/// Provides [GetWorkspaceSettings].
@riverpod
GetWorkspaceSettings getWorkspaceSettings(Ref ref) =>
    GetWorkspaceSettings(ref.watch(workspaceSettingsRepositoryProvider));

/// Provides [UpdateWorkspaceSettings].
@riverpod
UpdateWorkspaceSettings updateWorkspaceSettings(Ref ref) =>
    UpdateWorkspaceSettings(ref.watch(workspaceSettingsRepositoryProvider));

/// Provides [LoadLastWorkspaceId].
@riverpod
LoadLastWorkspaceId loadLastWorkspaceId(Ref ref) =>
    LoadLastWorkspaceId(ref.watch(workspaceSelectionStoreProvider));

/// Provides [SaveLastWorkspaceId].
@riverpod
SaveLastWorkspaceId saveLastWorkspaceId(Ref ref) =>
    SaveLastWorkspaceId(ref.watch(workspaceSelectionStoreProvider));

/// Provides [ListWorktrees].
@riverpod
ListWorktrees listWorktrees(Ref ref) =>
    ListWorktrees(ref.watch(workspaceRepositoryProvider));

/// Provides [RemoveWorktree].
@riverpod
RemoveWorktree removeWorktree(Ref ref) =>
    RemoveWorktree(ref.watch(workspaceRepositoryProvider));
