import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/runs_list_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Run history list page (`/runs`).
class RunsPage extends ConsumerWidget {
  /// Creates a [RunsPage].
  const new({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RunSummary run,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await HiveDialog.confirm(
      context: context,
      title: l10n.runsDeleteTitle,
      message: l10n.runsDeleteMessage(run.workflowName),
      confirmLabel: l10n.runsDeleteConfirm,
      cancelLabel: l10n.runsCancelAction,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(runsListControllerProvider.notifier).deleteRun(run.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final stateAsync = ref.watch(runsListControllerProvider);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HivePageHeader(
              title: l10n.navRuns,
              subtitle: l10n.runsPageSubtitle,
              actions: <Widget>[
                HiveButton(
                  key: const Key('runs_refresh_button'),
                  label: l10n.runsRefreshAction,
                  icon: HiveIcons.refresh,
                  variant: HiveButtonVariant.secondary,
                  onPressed: () => unawaited(
                    ref.read(runsListControllerProvider.notifier).refresh(),
                  ),
                ),
              ],
            ),
            Expanded(
              child: stateAsync.when(
                loading: () => Center(
                  child: HiveSpinner(
                    size: spacing.space4,
                    color: colors.accent,
                  ),
                ),
                error: (error, _) => HiveEmptyState(
                  icon: HiveIcons.alert,
                  title: l10n.runsLoadErrorTitle,
                  message: RunL10n.localizeError(l10n, error),
                  action: HiveButton(
                    label: l10n.runsRetryAction,
                    icon: HiveIcons.refresh,
                    onPressed: () => unawaited(
                      ref.read(runsListControllerProvider.notifier).refresh(),
                    ),
                  ),
                ),
                data: (listState) {
                  if (listState.runs.isEmpty && !listState.hasActiveFilters) {
                    return HiveFadeIn(
                      child: HiveEmptyState(
                        icon: HiveIcons.runs,
                        title: l10n.runsEmptyTitle,
                        message: l10n.runsEmptyDescription,
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _RunsFilterBar(state: listState),
                      if (listState.actionFailure != null) ...<Widget>[
                        SizedBox(height: spacing.space2),
                        HiveBadge(
                          label: RunL10n.localizeFailure(
                            l10n,
                            listState.actionFailure!,
                          ),
                          tone: HiveBadgeTone.danger,
                          icon: HiveIcons.alert,
                        ),
                      ],
                      SizedBox(height: spacing.space3),
                      Expanded(
                        child: listState.runs.isEmpty
                            ? HiveEmptyState(
                                icon: HiveIcons.search,
                                title: l10n.runsFilterEmptyTitle,
                                message: l10n.runsFilterEmptyDescription,
                                action: HiveButton(
                                  key: const Key('runs_clear_filters_button'),
                                  label: l10n.runsClearFiltersAction,
                                  variant: HiveButtonVariant.secondary,
                                  onPressed: () => unawaited(
                                    ref
                                        .read(
                                          runsListControllerProvider.notifier,
                                        )
                                        .clearFilters(),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: listState.runs.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: spacing.space2),
                                itemBuilder: (context, index) {
                                  final run = listState.runs[index];
                                  final isBusy = listState.busyRunId == run.id;
                                  final nodeStatus = RunL10n.nodeStatusFor(
                                    run.status,
                                  );
                                  final statusLabel = RunL10n.localizeStatus(
                                    l10n,
                                    run.status,
                                  );
                                  return HiveCard(
                                    key: Key('run_card_${run.id}'),
                                    surface: HiveCardSurface.surface2,
                                    semanticLabel:
                                        '${run.workflowName} - $statusLabel',
                                    onPressed: () =>
                                        RunDetailRoute(id: run.id).go(context),
                                    child: Row(
                                      children: <Widget>[
                                        HiveStatusDot(
                                          status: nodeStatus,
                                          semanticLabel: statusLabel,
                                          size: spacing.space2,
                                        ),
                                        SizedBox(width: spacing.space2),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  Flexible(
                                                    child: Text(
                                                      run.workflowName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: typography
                                                          .titleSmall
                                                          .copyWith(
                                                            color: colors
                                                                .onSurface,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: spacing.space2,
                                                  ),
                                                  HiveBadge(
                                                    label: statusLabel,
                                                    tone: RunL10n.badgeToneFor(
                                                      run.status,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: spacing.spaceHalf,
                                              ),
                                              Wrap(
                                                spacing: spacing.space3,
                                                runSpacing: spacing.spaceHalf,
                                                children: <Widget>[
                                                  Text(
                                                    RunL10n.formatTimestamp(
                                                      run.startedAt,
                                                    ),
                                                    style: typography.mono
                                                        .copyWith(
                                                          color: colors
                                                              .onSurfaceMuted,
                                                        ),
                                                  ),
                                                  Text(
                                                    RunL10n.formatDuration(
                                                      l10n,
                                                      run.startedAt,
                                                      run.finishedAt,
                                                    ),
                                                    style: typography.mono
                                                        .copyWith(
                                                          color: colors
                                                              .onSurfaceMuted,
                                                        ),
                                                  ),
                                                  Text(
                                                    l10n.runsCheckpointCount(
                                                      run.checkpointCount,
                                                    ),
                                                    style: typography.label
                                                        .copyWith(
                                                          color: colors
                                                              .onSurfaceMuted,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!run.status.isActive) ...<Widget>[
                                          SizedBox(width: spacing.space2),
                                          if (isBusy)
                                            HiveSpinner(
                                              size: spacing.space3,
                                              color: colors.accent,
                                            )
                                          else
                                            HiveIconButton(
                                              key: Key('run_delete_${run.id}'),
                                              icon: HiveIcons.delete,
                                              semanticLabel:
                                                  l10n.runsDeleteTooltip,
                                              onPressed: () => unawaited(
                                                _confirmDelete(
                                                  context,
                                                  ref,
                                                  run,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunsFilterBar extends ConsumerWidget {
  const new({required this.state});

  final RunsListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final controller = ref.read(runsListControllerProvider.notifier);

    final workflowOptions = <HiveSelectOption<String?>>[
      HiveSelectOption<String?>(value: null, label: l10n.runsFilterWorkflowAll),
      for (final workflow in state.workflows)
        HiveSelectOption<String?>(value: workflow.id, label: workflow.name),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Wrap(
            spacing: spacing.space1,
            runSpacing: spacing.space1,
            children: <Widget>[
              HiveFilterChip(
                key: const Key('runs_filter_all'),
                label: l10n.runsFilterAll,
                selected: state.statusFilter == null,
                onSelected: (_) => unawaited(controller.setStatusFilter(null)),
              ),
              for (final status in RunStatus.values)
                HiveFilterChip(
                  key: Key('runs_filter_${status.name}'),
                  label: RunL10n.localizeStatus(l10n, status),
                  selected: state.statusFilter == status,
                  leading: HiveStatusDot(
                    status: RunL10n.nodeStatusFor(status),
                    semanticLabel: RunL10n.localizeStatus(l10n, status),
                  ),
                  onSelected: (selected) => unawaited(
                    controller.setStatusFilter(selected ? status : null),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: spacing.space3),
        SizedBox(
          width: spacing.space8 * 3,
          child: HiveSelect<String?>(
            key: const Key('runs_workflow_select'),
            label: l10n.runsFilterWorkflowLabel,
            options: workflowOptions,
            value: state.workflowFilter,
            onChanged: (workflowId) =>
                unawaited(controller.setWorkflowFilter(workflowId)),
          ),
        ),
      ],
    );
  }
}
