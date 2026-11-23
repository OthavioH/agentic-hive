import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/side_rail_tree_controller.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Wireframe pass 1 tree displaying workspaces, worktrees, and active/recent
/// runs beside the navigation rail.
class SideRailTree extends ConsumerWidget {
  /// Creates a [SideRailTree].
  const new({required this.currentLocation, super.key});

  /// Current router path used to highlight the selected run item.
  final String currentLocation;

  Future<void> _startRunFromTree(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
    Worktree worktree,
  ) async {
    await ref
        .read(sideRailTreeControllerProvider.notifier)
        .selectWorkspace(workspace.id);
    if (!context.mounted) return;
    final created = await StartRunDialog.show(
      context,
      initialWorkspaceId: workspace.id,
      initialWorktreeId: worktree.id,
    );
    if (created != null && context.mounted) {
      RunDetailRoute(id: created.id).go(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final stateAsync = ref.watch(sideRailTreeControllerProvider);
    final controller = ref.read(sideRailTreeControllerProvider.notifier);
    final isRefreshing = stateAsync.asData?.value.isRefreshing ?? false;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: HiveCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.sideRailTreeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.titleSmall.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
                HiveIconButton(
                  key: const Key('side_rail_tree_refresh_button'),
                  icon: HiveIcons.refresh,
                  size: HiveButtonSize.small,
                  semanticLabel: l10n.sideRailTreeRefreshTooltip,
                  loading: isRefreshing,
                  onPressed: () => unawaited(controller.refresh()),
                ),
              ],
            ),
            SizedBox(height: spacing.space2),
            Expanded(
              child: switch (stateAsync) {
                AsyncLoading<SideRailTreeState>() => Center(
                  child: HiveSpinner(
                    size: spacing.space4,
                    color: colors.accent,
                  ),
                ),
                AsyncError<SideRailTreeState>(:final error) => HiveEmptyState(
                  icon: HiveIcons.alert,
                  title: l10n.sideRailTreeLoadErrorTitle,
                  message: RunL10n.localizeError(l10n, error),
                  action: HiveButton(
                    label: l10n.sideRailTreeRetryAction,
                    size: HiveButtonSize.small,
                    onPressed: () => unawaited(controller.refresh()),
                  ),
                ),
                AsyncData<SideRailTreeState>(:final value) =>
                  _SideRailTreeContent(
                    state: value,
                    currentLocation: currentLocation,
                    onSelectWorkspace: (id) =>
                        unawaited(controller.selectWorkspace(id)),
                    onToggleWorkspace: controller.toggleWorkspaceExpanded,
                    onToggleWorktree: controller.toggleWorktreeExpanded,
                    onToggleShowAllActive: controller.toggleShowAllActive,
                    onToggleShowAllRecent: controller.toggleShowAllRecent,
                    onStartRun: (ws, wt) =>
                        unawaited(_startRunFromTree(context, ref, ws, wt)),
                    onOpenRun: (runId) => RunDetailRoute(id: runId).go(context),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SideRailTreeContent extends ConsumerWidget {
  const new({
    required this.state,
    required this.currentLocation,
    required this.onSelectWorkspace,
    required this.onToggleWorkspace,
    required this.onToggleWorktree,
    required this.onToggleShowAllActive,
    required this.onToggleShowAllRecent,
    required this.onStartRun,
    required this.onOpenRun,
  });

  final SideRailTreeState state;
  final String currentLocation;
  final ValueChanged<String> onSelectWorkspace;
  final ValueChanged<String> onToggleWorkspace;
  final void Function(String workspaceId, String worktreeId) onToggleWorktree;
  final void Function(String workspaceId, String worktreeId)
  onToggleShowAllActive;
  final void Function(String workspaceId, String worktreeId)
  onToggleShowAllRecent;
  final void Function(Workspace workspace, Worktree worktree) onStartRun;
  final ValueChanged<String> onOpenRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    // Only tick while a run is active; finished runs show a fixed duration.
    final hasActiveRun = state.workspaces.any(
      (ws) => ws.worktrees.any((wt) => wt.activeRuns.isNotEmpty),
    );
    final now = hasActiveRun
        ? ref.watch(sideRailTreeNowProvider).value ??
              ref.read(sideRailTreeClockProvider)()
        : ref.read(sideRailTreeClockProvider)();

    if (state.workspaces.isEmpty) {
      return HiveEmptyState(
        icon: HiveIcons.folder,
        title: l10n.sideRailTreeEmptyTitle,
        message: l10n.sideRailTreeEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.refreshFailure != null) ...<Widget>[
          HiveBanner(
            tone: HiveFeedbackTone.danger,
            title: l10n.sideRailTreeLoadErrorTitle,
            message: RunL10n.localizeFailure(l10n, state.refreshFailure!),
          ),
          SizedBox(height: spacing.space2),
        ],
        Expanded(
          child: ListView(
            children: <Widget>[
              for (final wsNode in state.workspaces) ...<Widget>[
                HiveTreeItem(
                  key: Key('tree_workspace_${wsNode.workspace.id}'),
                  label: wsNode.workspace.name,
                  leading: HiveIcon(
                    HiveIcons.folder,
                    size: spacing.space2,
                    color: colors.onSurfaceMuted,
                  ),
                  expanded: wsNode.expanded,
                  expandSemanticLabel: wsNode.expanded
                      ? l10n.sideRailTreeCollapseWorkspace(
                          wsNode.workspace.name,
                        )
                      : l10n.sideRailTreeExpandWorkspace(wsNode.workspace.name),
                  onToggleExpand: () => onToggleWorkspace(wsNode.workspace.id),
                  selected: wsNode.workspace.id == state.currentWorkspaceId,
                  highlighted: wsNode.pendingPauseCount > 0,
                  trailing: _WorkspaceTrailingBadges(
                    activeRunCount: wsNode.activeRunCount,
                    pendingPauseCount: wsNode.pendingPauseCount,
                  ),
                  onPressed: () => onSelectWorkspace(wsNode.workspace.id),
                ),
                if (wsNode.expanded)
                  for (final wtNode in wsNode.worktrees)
                    ..._buildWorktreeSection(
                      context,
                      l10n,
                      spacing,
                      colors,
                      wsNode.workspace,
                      wtNode,
                      now,
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWorktreeSection(
    BuildContext context,
    AppLocalizations l10n,
    HiveSpacing spacing,
    HiveColors colors,
    Workspace workspace,
    SideRailWorktreeNode wtNode,
    DateTime now,
  ) {
    final wt = wtNode.worktree;
    final wtLabel = wt.isPrimary ? l10n.sideRailTreePrimaryLabel : wt.name;
    final wtSubtitle =
        wt.branch ?? (workspace.isGit ? l10n.sideRailTreeDetachedHead : null);

    final activeLimit = wtNode.showAllActive
        ? wtNode.activeRuns.length
        : SideRailTreeController.maxRunsPerGroup;
    final visibleActive = wtNode.activeRuns.take(activeLimit).toList();
    final remainingActive =
        wtNode.activeRuns.length - SideRailTreeController.maxRunsPerGroup;

    final recentLimit = wtNode.showAllRecent
        ? wtNode.recentRuns.length
        : SideRailTreeController.maxRunsPerGroup;
    final visibleRecent = wtNode.recentRuns.take(recentLimit).toList();
    final remainingRecent =
        wtNode.recentRuns.length - SideRailTreeController.maxRunsPerGroup;

    return <Widget>[
      HiveTreeItem(
        key: Key('tree_worktree_${workspace.id}_${wt.id}'),
        indentLevel: 1,
        label: wtLabel,
        subtitle: wtSubtitle,
        leading: HiveIcon(
          wt.isPrimary ? HiveIcons.folder : HiveIcons.branch,
          size: spacing.space2,
          color: colors.onSurfaceMuted,
        ),
        expanded: wtNode.expanded,
        expandSemanticLabel: wtNode.expanded
            ? l10n.sideRailTreeCollapseWorktree(wtLabel)
            : l10n.sideRailTreeExpandWorktree(wtLabel),
        onToggleExpand: () => onToggleWorktree(workspace.id, wt.id),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (wt.isPrimary && workspace.isGit)
              HiveBadge(
                label: l10n.sideRailTreePrimaryBadge,
                tone: HiveBadgeTone.accentMuted,
              ),
            if (wt.isPrimary && workspace.isGit && wt.hasUncommittedChanges)
              SizedBox(width: spacing.spaceHalf),
            if (wt.hasUncommittedChanges)
              HiveIcon(
                HiveIcons.edit,
                key: Key('tree_worktree_dirty_${workspace.id}_${wt.id}'),
                size: spacing.space2,
                color: colors.warning,
                semanticLabel: l10n.sideRailTreeDirtyBadge,
              ),
            SizedBox(width: spacing.spaceHalf),
            HiveIconButton(
              key: Key('tree_start_run_${workspace.id}_${wt.id}'),
              icon: HiveIcons.play,
              size: HiveButtonSize.small,
              semanticLabel: l10n.sideRailTreeStartRunTooltip(wtLabel),
              onPressed: () => onStartRun(workspace, wt),
            ),
          ],
        ),
        onPressed: () => onSelectWorkspace(workspace.id),
      ),
      if (wtNode.expanded) ...<Widget>[
        if (wtNode.activeRuns.isEmpty && wtNode.recentRuns.isEmpty)
          HiveTreeItem(
            indentLevel: 2,
            label: l10n.sideRailTreeNoRuns,
            onPressed: null,
          ),
        for (final run in visibleActive) _buildRunItem(l10n, run, now),
        if (wtNode.activeRuns.length > SideRailTreeController.maxRunsPerGroup)
          HiveTreeItem(
            key: Key('tree_see_all_active_${workspace.id}_${wt.id}'),
            indentLevel: 2,
            label: wtNode.showAllActive
                ? l10n.sideRailTreeShowLess
                : l10n.sideRailTreeSeeAll(remainingActive),
            onPressed: () => onToggleShowAllActive(workspace.id, wt.id),
          ),
        for (final run in visibleRecent) _buildRunItem(l10n, run, now),
        if (wtNode.recentRuns.length > SideRailTreeController.maxRunsPerGroup)
          HiveTreeItem(
            key: Key('tree_see_all_recent_${workspace.id}_${wt.id}'),
            indentLevel: 2,
            label: wtNode.showAllRecent
                ? l10n.sideRailTreeShowLess
                : l10n.sideRailTreeSeeAll(remainingRecent),
            onPressed: () => onToggleShowAllRecent(workspace.id, wt.id),
          ),
      ],
    ];
  }

  Widget _buildRunItem(AppLocalizations l10n, RunSummary run, DateTime now) {
    final isPendingPause = state.pendingPauseRunIds.contains(run.id);
    final elapsed = RunL10n.formatDuration(
      l10n,
      run.status,
      run.startedAt,
      run.finishedAt ?? (run.status.isActive ? now : null),
    );
    return HiveTreeItem(
      key: Key('tree_run_${run.id}'),
      indentLevel: 2,
      label: run.workflowName,
      subtitle: elapsed,
      leading: HiveStatusDot(
        status: RunL10n.nodeStatusFor(run.status),
        semanticLabel: RunL10n.localizeStatus(l10n, run.status),
      ),
      selected: currentLocation == '/runs/${run.id}',
      highlighted: isPendingPause,
      onPressed: () => onOpenRun(run.id),
    );
  }
}

class _WorkspaceTrailingBadges extends StatelessWidget {
  const new({required this.activeRunCount, required this.pendingPauseCount});

  final int activeRunCount;
  final int pendingPauseCount;

  @override
  Widget build(BuildContext context) {
    if (activeRunCount == 0 && pendingPauseCount == 0) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (activeRunCount > 0)
          HiveBadge(
            label: '$activeRunCount',
            tone: HiveBadgeTone.info,
            semanticLabel: l10n.sideRailTreeActiveRunsSemantic(activeRunCount),
          ),
        if (activeRunCount > 0 && pendingPauseCount > 0)
          SizedBox(width: spacing.spaceHalf),
        if (pendingPauseCount > 0)
          HiveBadge(
            label: '$pendingPauseCount',
            tone: HiveBadgeTone.warning,
            icon: HiveIcons.pause,
            semanticLabel: l10n.sideRailTreePendingPausesSemantic(
              pendingPauseCount,
            ),
          ),
      ],
    );
  }
}
