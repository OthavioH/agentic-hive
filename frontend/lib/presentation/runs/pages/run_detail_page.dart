import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/run_graph_view.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/run_inspector_tabs.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/run_output_panel.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/snapshots_panel.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Detail page for a single run (`/runs/:id`) showing summary metadata,
/// chronological event log, and checkpoint inspector.
class RunDetailPage extends ConsumerWidget {
  /// Creates a [RunDetailPage] for [runId].
  const new({required this.runId, super.key});

  /// ID of the run to inspect.
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final stateAsync = ref.watch(runDetailControllerProvider(runId));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: context.hiveRadii.panel,
        border: Border.all(
          color: colors.borderSubtle,
          width: context.hiveElevation.hairline,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.space4),
        child: stateAsync.when(
          loading: () => Center(
            child: HiveSpinner(size: spacing.space4, color: colors.accent),
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _HeaderRow(
                title: l10n.navRuns,
                onBack: () => const RunsRoute().go(context),
              ),
              Expanded(
                child: HiveEmptyState(
                  icon: HiveIcons.alert,
                  title: l10n.runDetailLoadErrorTitle,
                  message: RunL10n.localizeError(l10n, error),
                  action: HiveButton(
                    label: l10n.runsRetryAction,
                    icon: HiveIcons.refresh,
                    onPressed: () => unawaited(
                      ref
                          .read(runDetailControllerProvider(runId).notifier)
                          .refresh(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          data: (detailState) => _RunDetailBody(
            runId: runId,
            detailState: detailState,
            onBack: () => const RunsRoute().go(context),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const new({
    required this.title,
    required this.onBack,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        HiveIconButton(
          key: const Key('run_detail_back_button'),
          icon: HiveIcons.collapseRail,
          semanticLabel: l10n.runDetailBackTooltip,
          onPressed: onBack,
        ),
        SizedBox(width: spacing.space2),
        Expanded(
          child: HivePageHeader(
            title: title,
            subtitle: subtitle,
            actions: actions,
          ),
        ),
      ],
    );
  }
}

class _RunDetailBody extends ConsumerStatefulWidget {
  const new({
    required this.runId,
    required this.detailState,
    required this.onBack,
  });

  final String runId;
  final RunDetailState detailState;
  final VoidCallback onBack;

  @override
  ConsumerState<_RunDetailBody> createState() => _RunDetailBodyState();
}

class _RunDetailBodyState extends ConsumerState<_RunDetailBody> {
  RunInspectorTab _tab = RunInspectorTab.output;

  String get runId => widget.runId;
  RunDetailState get detailState => widget.detailState;
  VoidCallback get onBack => widget.onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final controller = ref.read(runDetailControllerProvider(runId).notifier);
    final run = detailState.run;
    final statusLabel = RunL10n.localizeStatus(l10n, run.status);
    final isCancelling = run.status == RunStatus.cancelling;
    final showCancel =
        run.status == RunStatus.running ||
        run.status == RunStatus.paused ||
        isCancelling;
    final showRetryCancel = run.status == RunStatus.cancellationUncertain;
    final showResume = run.status == RunStatus.interrupted;

    final graphView = RunGraphView(
      workflow: run.workflowDefinition,
      nodeStatuses: detailState.nodeStatuses,
      selectedNodeId: detailState.inspectedNodeId,
      onSelectNode: (nodeId) => unawaited(controller.selectNode(nodeId)),
    );
    final inspector = _InspectorColumn(
      runId: runId,
      detailState: detailState,
      tab: _tab,
      onTabChanged: (tab) => setState(() => _tab = tab),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HeaderRow(
          title: run.workflowName,
          subtitle: run.workspacePath,
          onBack: onBack,
          actions: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                HiveStatusDot(
                  status: RunL10n.nodeStatusFor(run.status),
                  semanticLabel: statusLabel,
                  size: spacing.space2,
                ),
                SizedBox(width: spacing.space1),
                HiveBadge(
                  label: statusLabel,
                  tone: RunL10n.badgeToneFor(run.status),
                ),
              ],
            ),
            if (showCancel)
              HiveButton(
                key: const Key('run_detail_cancel_button'),
                label: isCancelling
                    ? l10n.runDetailCancellingAction
                    : l10n.runDetailCancelAction,
                icon: HiveIcons.stop,
                variant: HiveButtonVariant.danger,
                loading: isCancelling || detailState.isActionInFlight,
                onPressed: (isCancelling || detailState.isActionInFlight)
                    ? null
                    : () => unawaited(controller.cancelRun()),
              ),
            if (showRetryCancel)
              HiveButton(
                key: const Key('run_detail_retry_cancel_button'),
                label: l10n.runDetailRetryCancelAction,
                icon: HiveIcons.stop,
                variant: HiveButtonVariant.danger,
                loading: detailState.isActionInFlight,
                onPressed: detailState.isActionInFlight
                    ? null
                    : () => unawaited(controller.cancelRun()),
              ),
            if (showResume)
              HiveButton(
                key: const Key('run_detail_resume_button'),
                label: detailState.isActionInFlight
                    ? l10n.runDetailResumingAction
                    : l10n.runDetailResumeAction,
                icon: HiveIcons.play,
                loading: detailState.isActionInFlight,
                onPressed: detailState.isActionInFlight
                    ? null
                    : () => unawaited(controller.resumeRun()),
              ),
            HiveButton(
              key: const Key('run_detail_refresh_button'),
              label: l10n.runsRefreshAction,
              icon: HiveIcons.refresh,
              variant: HiveButtonVariant.secondary,
              loading: detailState.isRefreshing,
              onPressed: () => unawaited(controller.refresh()),
            ),
          ],
        ),
        if (detailState.actionFailure != null) ...<Widget>[
          HiveBanner(
            key: const Key('run_detail_action_failure_banner'),
            tone: HiveFeedbackTone.danger,
            title: RunL10n.localizeFailure(l10n, detailState.actionFailure!),
            onDismiss: controller.dismissActionFailure,
            dismissSemanticLabel: l10n.snapshotsDismissTooltip,
            liveRegion: true,
          ),
          SizedBox(height: spacing.space2),
        ],
        HiveCard(
          surface: HiveCardSurface.surface2,
          child: Wrap(
            spacing: spacing.space4,
            runSpacing: spacing.space2,
            children: <Widget>[
              _MetadataItem(
                label: l10n.runDetailWorkspaceLabel,
                value: run.workspacePath,
                mono: true,
              ),
              _MetadataItem(
                label: l10n.runDetailIsolationLabel,
                value: switch (run.isolationMode) {
                  WorkspaceIsolationMode.direct =>
                    l10n.runDetailIsolationDirect,
                  WorkspaceIsolationMode.worktree =>
                    l10n.runDetailIsolationWorktree,
                },
              ),
              if (run.worktreePath != null)
                _MetadataItem(
                  key: const Key('run_detail_worktree_path'),
                  label: l10n.runDetailWorktreePathLabel,
                  value: run.worktreePath!,
                  mono: true,
                ),
              if (run.worktreeBranch != null)
                _MetadataItem(
                  key: const Key('run_detail_worktree_branch'),
                  label: l10n.runDetailWorktreeBranchLabel,
                  value: run.worktreeBranch!,
                  mono: true,
                ),
              _MetadataItem(
                label: l10n.runDetailStartedLabel,
                value: RunL10n.formatTimestamp(run.startedAt),
                mono: true,
              ),
              if (run.finishedAt != null)
                _MetadataItem(
                  label: l10n.runDetailFinishedLabel,
                  value: RunL10n.formatTimestamp(run.finishedAt!),
                  mono: true,
                ),
              _MetadataItem(
                label: l10n.runDetailDurationLabel,
                value: RunL10n.formatDuration(
                  l10n,
                  run.status,
                  run.startedAt,
                  run.finishedAt,
                ),
                mono: true,
              ),
            ],
          ),
        ),
        if (run.errorMessage != null &&
            run.errorMessage!.isNotEmpty) ...<Widget>[
          SizedBox(height: spacing.space2),
          HiveCard(
            key: const Key('run_detail_error_card'),
            surface: HiveCardSurface.surface2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                HiveIcon(
                  HiveIcons.alert,
                  size: spacing.space3,
                  color: colors.danger,
                ),
                SizedBox(width: spacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.runDetailErrorLabel,
                        style: typography.label.copyWith(color: colors.danger),
                      ),
                      SizedBox(height: spacing.spaceHalf),
                      SelectableText(
                        run.errorMessage!,
                        style: typography.mono.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: spacing.space3),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 840) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 3, child: graphView),
                    SizedBox(width: spacing.space3),
                    Expanded(flex: 2, child: inspector),
                  ],
                );
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(height: spacing.space8 * 6, child: graphView),
                    SizedBox(height: spacing.space3),
                    SizedBox(height: spacing.space8 * 6, child: inspector),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    this.mono = false,
    super.key,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final spacing = context.hiveSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: typography.label.copyWith(color: colors.onSurfaceMuted),
        ),
        SizedBox(height: spacing.spaceHalf),
        Text(
          value,
          style: (mono ? typography.mono : typography.body).copyWith(
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _EventTimelineColumn extends ConsumerWidget {
  const new({
    required this.runId,
    required this.events,
    required this.expandedEventIds,
  });

  final String runId;
  final List<RunEvent> events;
  final Set<String> expandedEventIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;

    return HiveCard(
      surface: HiveCardSurface.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.runDetailEventsTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space2),
          Expanded(
            child: events.isEmpty
                ? HiveEmptyState(
                    icon: HiveIcons.terminal,
                    title: l10n.runDetailEventsTitle,
                    message: l10n.runDetailEventsEmpty,
                  )
                : ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: spacing.space2),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isExpanded = expandedEventIds.contains(event.id);
                      final hasPayload = event.payload.isNotEmpty;
                      return HiveCard(
                        key: Key('run_event_${event.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(
                                  '#${event.sequence}',
                                  style: typography.mono.copyWith(
                                    color: colors.onSurfaceMuted,
                                  ),
                                ),
                                SizedBox(width: spacing.space2),
                                HiveBadge(
                                  label: event.type.wireName,
                                  tone: RunL10n.eventToneFor(event.type),
                                ),
                                SizedBox(width: spacing.space2),
                                Expanded(
                                  child: Text(
                                    RunL10n.formatTimestamp(event.createdAt),
                                    style: typography.mono.copyWith(
                                      color: colors.onSurfaceMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasPayload)
                                  HiveIconButton(
                                    key: Key('run_event_toggle_${event.id}'),
                                    icon: HiveIcons.chevronDown,
                                    size: HiveButtonSize.small,
                                    semanticLabel: isExpanded
                                        ? l10n.runDetailCollapsePayloadTooltip
                                        : l10n.runDetailExpandPayloadTooltip,
                                    onPressed: () => ref
                                        .read(
                                          runDetailControllerProvider(runId)
                                              .notifier,
                                        )
                                        .toggleEventExpanded(event.id),
                                  ),
                              ],
                            ),
                            if (event.nodeId != null ||
                                event.edgeId != null) ...<Widget>[
                              SizedBox(height: spacing.space1),
                              Wrap(
                                spacing: spacing.space2,
                                runSpacing: spacing.spaceHalf,
                                children: <Widget>[
                                  if (event.nodeId != null)
                                    Text(
                                      l10n.runDetailNodeLabel(event.nodeId!),
                                      style: typography.mono.copyWith(
                                        color: colors.onSurfaceMuted,
                                      ),
                                    ),
                                  if (event.edgeId != null)
                                    Text(
                                      l10n.runDetailEdgeLabel(event.edgeId!),
                                      style: typography.mono.copyWith(
                                        color: colors.onSurfaceMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (isExpanded) ...<Widget>[
                              SizedBox(height: spacing.space2),
                              HiveCodeBlock(
                                key: Key('run_event_payload_${event.id}'),
                                title: l10n.runDetailEventPayloadTitle,
                                code: RunL10n.prettyJsonMap(event.payload),
                                copyLabel: l10n.runDetailCopyLabel,
                                emptyLabel: l10n.runDetailEventPayloadEmpty,
                                maxHeight: spacing.space8 * 3,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InspectorColumn extends StatelessWidget {
  const new({
    required this.runId,
    required this.detailState,
    required this.tab,
    required this.onTabChanged,
  });

  final String runId;
  final RunDetailState detailState;
  final RunInspectorTab tab;
  final ValueChanged<RunInspectorTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final run = detailState.run;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: RunInspectorTabs(selected: tab, onChanged: onTabChanged),
          ),
        ),
        SizedBox(height: spacing.space2),
        Expanded(
          child: switch (tab) {
            RunInspectorTab.output => RunOutputPanel(
              runId: runId,
              detailState: detailState,
            ),
            RunInspectorTab.events => _EventTimelineColumn(
              runId: runId,
              events: detailState.events,
              expandedEventIds: detailState.expandedEventIds,
            ),
            RunInspectorTab.checkpoints => _CheckpointInspectorColumn(
              runId: runId,
              checkpoints: detailState.checkpoints,
              selectedCheckpoint: detailState.selectedCheckpoint,
            ),
            RunInspectorTab.snapshots => SnapshotsPanel(
              runId: runId,
              workspacePath: run.workspacePath,
              runStatus: run.status,
              nodeLabels: <String, String>{
                for (final node in run.workflowDefinition.nodes)
                  node.id: node.label,
              },
            ),
          },
        ),
      ],
    );
  }
}

class _CheckpointInspectorColumn extends ConsumerWidget {
  const new({
    required this.runId,
    required this.checkpoints,
    required this.selectedCheckpoint,
  });

  final String runId;
  final List<Checkpoint> checkpoints;
  final Checkpoint? selectedCheckpoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;

    return HiveCard(
      surface: HiveCardSurface.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.runDetailCheckpointsTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space2),
          if (checkpoints.isEmpty || selectedCheckpoint == null)
            Expanded(
              child: HiveEmptyState(
                icon: HiveIcons.branch,
                title: l10n.runDetailCheckpointsTitle,
                message: l10n.runDetailCheckpointsEmpty,
              ),
            )
          else ...<Widget>[
            Wrap(
              spacing: spacing.space1,
              runSpacing: spacing.space1,
              children: <Widget>[
                for (final checkpoint in checkpoints)
                  HiveFilterChip(
                    key: Key('checkpoint_chip_${checkpoint.id}'),
                    label: l10n.runDetailCheckpointSequence(
                      checkpoint.sequence,
                    ),
                    selected: selectedCheckpoint!.id == checkpoint.id,
                    onSelected: (_) => ref
                        .read(runDetailControllerProvider(runId).notifier)
                        .selectCheckpoint(checkpoint.id),
                  ),
              ],
            ),
            SizedBox(height: spacing.space3),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _MetadataItem(
                      label: l10n.runDetailCompletedNodeLabel,
                      value:
                          selectedCheckpoint!.completedNodeId ??
                          l10n.runDetailNone,
                      mono: true,
                    ),
                    SizedBox(height: spacing.space2),
                    _MetadataItem(
                      label: l10n.runDetailPendingNodesLabel,
                      value: selectedCheckpoint!.pendingNodeIds.isEmpty
                          ? l10n.runDetailNone
                          : selectedCheckpoint!.pendingNodeIds.join(', '),
                      mono: true,
                    ),
                    SizedBox(height: spacing.space2),
                    _MetadataItem(
                      label: l10n.runDetailAttemptsLabel,
                      value: selectedCheckpoint!.attemptsByEdge.isEmpty
                          ? l10n.runDetailNone
                          : selectedCheckpoint!.attemptsByEdge.entries
                                .map((e) => '${e.key}: ${e.value}')
                                .join(', '),
                      mono: true,
                    ),
                    SizedBox(height: spacing.space2),
                    _MetadataItem(
                      label: l10n.runDetailCircuitBreakerLabel,
                      value: '${selectedCheckpoint!.circuitBreakerCount}',
                      mono: true,
                    ),
                    SizedBox(height: spacing.space3),
                    HiveCodeBlock(
                      key: const Key('checkpoint_node_outputs_block'),
                      title: l10n.runDetailNodeOutputsLabel,
                      code: RunL10n.prettyJsonMap(
                        selectedCheckpoint!.nodeOutputs,
                      ),
                      copyLabel: l10n.runDetailCopyLabel,
                      emptyLabel: l10n.runDetailNoOutputs,
                      maxHeight: spacing.space8 * 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
