import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/runs_list_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/run_list_card.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
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

  Future<void> _startNewRun(BuildContext context) async {
    final created = await StartRunDialog.show(context);
    if (created != null && context.mounted) {
      RunDetailRoute(id: created.id).go(context);
    }
  }

  Widget _buildRunsList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HiveSpacing spacing,
    RunsListState listState,
  ) {
    final rows = <_RunRow>[];
    for (final run in listState.topLevelRuns) {
      final kids = listState.childrenOf(run.id);
      final isExpanded = listState.expandedRunIds.contains(run.id);
      rows.add((run: run, nested: false, childCount: kids.length));
      if (isExpanded) {
        for (final kid in kids) {
          rows.add((run: kid, nested: true, childCount: 0));
        }
      }
    }

    return ListView.separated(
      itemCount: rows.length + (listState.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => SizedBox(height: spacing.space2),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          final notifier = ref.read(runsListControllerProvider.notifier);
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.space2),
              child: HiveButton(
                key: const Key('runs_load_more_button'),
                label: l10n.runsLoadMoreAction,
                variant: HiveButtonVariant.secondary,
                loading: listState.isLoadingMore,
                onPressed: listState.isLoadingMore
                    ? null
                    : () => unawaited(notifier.loadMore()),
              ),
            ),
          );
        }

        final row = rows[index];
        final run = row.run;
        return RunListCard(
          run: run,
          isBusy: listState.busyRunId == run.id,
          childCount: row.childCount,
          expanded: listState.expandedRunIds.contains(run.id),
          indented: row.nested,
          onOpen: () => RunDetailRoute(id: run.id).go(context),
          onDelete: () => unawaited(_confirmDelete(context, ref, run)),
          onToggleChildren: row.childCount > 0
              ? () => ref
                    .read(runsListControllerProvider.notifier)
                    .toggleExpanded(run.id)
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
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
                  loading: stateAsync.asData?.value.isRefreshing ?? false,
                  onPressed: () => unawaited(
                    ref.read(runsListControllerProvider.notifier).refresh(),
                  ),
                ),
                HiveButton(
                  key: const Key('runs_new_button'),
                  label: l10n.runsNewAction,
                  icon: HiveIcons.play,
                  onPressed: () => unawaited(_startNewRun(context)),
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
                  if (listState.isGlobalSelected) {
                    return HiveFadeIn(
                      child: HiveEmptyState(
                        icon: HiveIcons.runs,
                        title: l10n.runsGlobalEmptyTitle,
                        message: l10n.runsGlobalEmptyDescription,
                      ),
                    );
                  }
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
                            : _buildRunsList(
                                context,
                                ref,
                                l10n,
                                spacing,
                                listState,
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

typedef _RunRow = ({RunSummary run, bool nested, int childCount});

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
