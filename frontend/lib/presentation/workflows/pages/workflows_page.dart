import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_delete_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflows_list_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/utils/workflow_l10n.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_delete_notice_banner.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_deleting_badge.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Saved workflows list page (`/workflows`).
class WorkflowsPage extends ConsumerStatefulWidget {
  /// Creates a [WorkflowsPage].
  const new({super.key});

  @override
  ConsumerState<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends ConsumerState<WorkflowsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final workspace = ref
        .read(workspaceRegistryControllerProvider)
        .value
        ?.currentWorkspace;
    final created = await HiveDialog.show<_CreatedWorkflow>(
      context: context,
      barrierLabel: l10n.workflowsCancelAction,
      builder: (dialogContext) => _CreateWorkflowDialog(
        workspaceName: workspace?.name,
        onCreate: (name, description, global) async {
          final workspaceId = global ? null : workspace?.id;
          final result = await ref
              .read(workflowsListControllerProvider.notifier)
              .createWorkflow(
                name: name,
                description: description,
                workspaceId: workspaceId,
              );
          return result.map(
            (workflow) => (workflow: workflow, workspaceId: workspaceId),
          );
        },
      ),
    );

    if (created != null && context.mounted) {
      WorkflowEditorRoute(
        id: created.workflow.id,
        workspaceId: created.workspaceId,
      ).go(context);
    }
  }

  Future<void> _showStartRunDialog(
    BuildContext context,
    String workflowId,
  ) async {
    final created = await StartRunDialog.show(
      context,
      initialWorkflowId: workflowId,
    );
    if (created != null && context.mounted) {
      RunDetailRoute(id: created.id).go(context);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WorkflowSummary workflow,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showHiveConfirmDialog(
      context,
      title: l10n.workflowsDeleteTitle,
      message: l10n.workflowsDeleteMessage(workflow.name),
      confirmLabel: l10n.workflowsDeleteConfirm,
      cancelLabel: l10n.workflowsCancelAction,
      tone: HiveConfirmTone.destructive,
    );
    if (choice != HiveConfirmChoice.confirm || !context.mounted) return;
    await _runDelete(context, workflow, force: false);
  }

  /// Sends the delete request and asks to stop active runs while the backend
  /// refuses over them (BR4).
  Future<void> _runDelete(
    BuildContext context,
    WorkflowSummary workflow, {
    required bool force,
  }) async {
    final notifier = ref.read(workflowDeleteControllerProvider.notifier);
    final deleteWorkflow = ref.read(deleteWorkflowProvider);
    var outcome = await notifier.delete(deleteWorkflow, workflow, force: force);
    while (outcome is WorkflowDeleteNeedsForce) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final choice = await showHiveConfirmDialog(
        context,
        title: l10n.workflowsDeleteTitle,
        message: l10n.workflowsDeleteActiveRunsMessage(
          outcome.activeRunCount,
          workflow.name,
        ),
        confirmLabel: l10n.workflowsDeleteStopRunsConfirm,
        cancelLabel: l10n.workflowsCancelAction,
        tone: HiveConfirmTone.destructive,
      );
      if (choice != HiveConfirmChoice.confirm || !context.mounted) return;
      outcome = await notifier.delete(deleteWorkflow, workflow, force: true);
    }
  }

  /// After a revision conflict: drops the notice, reloads the list and asks
  /// again with the fresh revision (owner decision, plan section 8).
  Future<void> _reloadAndConfirm(
    BuildContext context,
    WorkflowSummary workflow,
  ) async {
    ref.read(workflowDeleteControllerProvider.notifier).dismissNotice();
    final listController = ref.read(workflowsListControllerProvider.notifier);
    await listController.refresh();
    if (!context.mounted) return;
    final listed = ref
        .read(workflowsListControllerProvider)
        .asData
        ?.value
        .workflows;
    final fresh = listed?.where(
      (candidate) =>
          candidate.id == workflow.id &&
          candidate.workspaceId == workflow.workspaceId,
    );
    if (fresh == null || fresh.isEmpty) return;
    await _confirmDelete(context, fresh.first);
  }

  /// Retry re-sends the failed request without the first confirmation.
  void _retryDelete(BuildContext context, WorkflowDeleteNotice notice) {
    if (notice case WorkflowDeleteFailedNotice(:final workflow, :final force)) {
      unawaited(_runDelete(context, workflow, force: force));
    }
  }

  void _reloadFailedDelete(BuildContext context, WorkflowDeleteNotice notice) {
    if (notice case WorkflowDeleteFailedNotice(:final workflow)) {
      unawaited(_reloadAndConfirm(context, workflow));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final stateAsync = ref.watch(workflowsListControllerProvider);
    final deleteState = ref.watch(workflowDeleteControllerProvider);

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
              title: l10n.navWorkflows,
              subtitle: l10n.workflowsPageSubtitle,
              actions: <Widget>[
                HiveButton(
                  key: const Key('workflows_new_button'),
                  label: l10n.workflowsNewAction,
                  icon: HiveIcons.add,
                  onPressed: () => unawaited(_showCreateDialog(context)),
                ),
              ],
            ),
            if (deleteState.notice case final notice?) ...<Widget>[
              WorkflowDeleteNoticeBanner(
                notice: notice,
                onDismiss: ref
                    .read(workflowDeleteControllerProvider.notifier)
                    .dismissNotice,
                onRetry: () => _retryDelete(context, notice),
                onReload: () => _reloadFailedDelete(context, notice),
              ),
              SizedBox(height: spacing.space2),
            ],
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
                  title: l10n.workflowsLoadErrorTitle,
                  message: WorkflowL10n.localizeError(l10n, error),
                  action: HiveButton(
                    label: l10n.workflowsRetryAction,
                    icon: HiveIcons.refresh,
                    onPressed: () => unawaited(
                      ref
                          .read(workflowsListControllerProvider.notifier)
                          .refresh(),
                    ),
                  ),
                ),
                data: (listState) {
                  if (listState.workflows.isEmpty) {
                    return HiveFadeIn(
                      child: HiveEmptyState(
                        icon: HiveIcons.workflows,
                        title: l10n.workflowsEmptyTitle,
                        message: l10n.workflowsEmptyDescription,
                        action: HiveButton(
                          label: l10n.workflowsNewAction,
                          icon: HiveIcons.add,
                          onPressed: () =>
                              unawaited(_showCreateDialog(context)),
                        ),
                      ),
                    );
                  }

                  final filtered = listState.filteredWorkflows;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      HiveTextField(
                        key: const Key('workflows_search_field'),
                        label: l10n.workflowsSearchLabel,
                        hint: l10n.workflowsSearchHint,
                        controller: _searchController,
                        onChanged: (value) => ref
                            .read(workflowsListControllerProvider.notifier)
                            .setSearchQuery(value),
                      ),
                      if (listState.actionFailure != null) ...<Widget>[
                        SizedBox(height: spacing.space2),
                        HiveBadge(
                          label: WorkflowL10n.localizeFailure(
                            l10n,
                            listState.actionFailure!,
                          ),
                          tone: HiveBadgeTone.danger,
                          icon: HiveIcons.alert,
                        ),
                      ],
                      SizedBox(height: spacing.space3),
                      Expanded(
                        child: filtered.isEmpty
                            ? HiveEmptyState(
                                icon: HiveIcons.search,
                                title: l10n.workflowsSearchEmptyTitle,
                                message: l10n.workflowsSearchEmptyDescription,
                                action: HiveButton(
                                  label: l10n.workflowsClearSearchAction,
                                  variant: HiveButtonVariant.secondary,
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          workflowsListControllerProvider
                                              .notifier,
                                        )
                                        .setSearchQuery('');
                                  },
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: spacing.space2),
                                itemBuilder: (context, index) {
                                  final controller = ref.read(
                                    workflowsListControllerProvider.notifier,
                                  );
                                  final summary = filtered[index];
                                  final deletion = deleteState
                                      .progress[workflowKeyOf(summary)];
                                  final isDeleting =
                                      summary.deleting || deletion != null;
                                  // Disabled while duplicating or deleting.
                                  final isBusy =
                                      listState.busyWorkflowId == summary.id ||
                                      isDeleting;
                                  final deletingReason = isDeleting
                                      ? l10n.workflowsActionUnavailableDeleting
                                      : null;
                                  final formattedDate = DateFormat.yMMMd()
                                      .add_Hm()
                                      .format(summary.updatedAt.toLocal());
                                  final hasErrors = summary.hasValidationErrors;
                                  final isWorkspaceScope =
                                      summary.scope == WorkflowScope.workspace;
                                  final scopeLabel = isWorkspaceScope
                                      ? l10n.workflowsScopeWorkspaceBadge
                                      : l10n.workflowsScopeGlobalBadge;
                                  final statusLabel = hasErrors
                                      ? l10n.workflowsStatusInvalid
                                      : l10n.workflowsStatusValid;
                                  final statusTone = hasErrors
                                      ? HiveBadgeTone.danger
                                      : HiveBadgeTone.success;

                                  return HiveCard(
                                    key: Key('workflow_card_${summary.id}'),
                                    surface: HiveCardSurface.surface2,
                                    busy: isDeleting,
                                    statusLabel: isDeleting
                                        ? workflowDeletingLabel(l10n, deletion)
                                        : null,
                                    semanticLabel: l10n.workflowsOpenAction(
                                      summary.name,
                                    ),
                                    onPressed: isBusy
                                        ? null
                                        : () => WorkflowEditorRoute(
                                            id: summary.id,
                                            workspaceId: summary.workspaceId,
                                          ).go(context),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  Flexible(
                                                    child: Text(
                                                      summary.name,
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
                                                    tone: statusTone,
                                                  ),
                                                  SizedBox(
                                                    width: spacing.space1,
                                                  ),
                                                  HiveBadge(
                                                    key: Key(
                                                      'scope_${summary.id}',
                                                    ),
                                                    label: scopeLabel,
                                                    tone: isWorkspaceScope
                                                        ? HiveBadgeTone
                                                              .accentMuted
                                                        : HiveBadgeTone.neutral,
                                                  ),
                                                ],
                                              ),
                                              if (isDeleting) ...<Widget>[
                                                SizedBox(
                                                  height: spacing.spaceHalf,
                                                ),
                                                WorkflowDeletingBadge(
                                                  workflowId: summary.id,
                                                  progress: deletion,
                                                ),
                                              ],
                                              if (summary.description != null &&
                                                  summary
                                                      .description!
                                                      .isNotEmpty) ...<Widget>[
                                                SizedBox(
                                                  height: spacing.spaceHalf,
                                                ),
                                                Text(
                                                  summary.description!,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: typography.bodySmall
                                                      .copyWith(
                                                        color: colors
                                                            .onSurfaceMuted,
                                                      ),
                                                ),
                                              ],
                                              SizedBox(height: spacing.space1),
                                              Wrap(
                                                spacing: spacing.space2,
                                                runSpacing: spacing.spaceHalf,
                                                children: <Widget>[
                                                  Text(
                                                    l10n.workflowsNodeCount(
                                                      summary.nodeCount,
                                                    ),
                                                    style: typography.bodySmall
                                                        .copyWith(
                                                          color: colors
                                                              .onSurfaceMuted,
                                                        ),
                                                  ),
                                                  Text(
                                                    l10n.workflowsEdgeCount(
                                                      summary.edgeCount,
                                                    ),
                                                    style: typography.bodySmall
                                                        .copyWith(
                                                          color: colors
                                                              .onSurfaceMuted,
                                                        ),
                                                  ),
                                                  Text(
                                                    l10n.workflowsUpdatedLabel(
                                                      formattedDate,
                                                    ),
                                                    style: typography.bodySmall
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
                                        SizedBox(width: spacing.space2),
                                        HiveIconButton(
                                          key: Key(
                                            'run_workflow_${summary.id}',
                                          ),
                                          icon: HiveIcons.play,
                                          semanticLabel:
                                              l10n.workflowsRunAction,
                                          disabledReason: deletingReason,
                                          onPressed: isBusy
                                              ? null
                                              : () => unawaited(
                                                  _showStartRunDialog(
                                                    context,
                                                    summary.id,
                                                  ),
                                                ),
                                        ),
                                        SizedBox(width: spacing.space1),
                                        HiveIconButton(
                                          key: Key(
                                            'duplicate_workflow_${summary.id}',
                                          ),
                                          icon: HiveIcons.copy,
                                          semanticLabel:
                                              l10n.workflowsDuplicateAction,
                                          disabledReason: deletingReason,
                                          onPressed: isBusy
                                              ? null
                                              : () => unawaited(
                                                  controller.duplicateWorkflow(
                                                    summary.id,
                                                    workspaceId:
                                                        summary.workspaceId,
                                                  ),
                                                ),
                                        ),
                                        SizedBox(width: spacing.space1),
                                        HiveIconButton(
                                          key: Key(
                                            'delete_workflow_${summary.id}',
                                          ),
                                          icon: HiveIcons.delete,
                                          semanticLabel:
                                              l10n.workflowsDeleteAction,
                                          disabledReason: deletingReason,
                                          onPressed: isBusy
                                              ? null
                                              : () => unawaited(
                                                  _confirmDelete(
                                                    context,
                                                    summary,
                                                  ),
                                                ),
                                        ),
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

typedef _CreatedWorkflow = ({Workflow workflow, String? workspaceId});

class _CreateWorkflowDialog extends StatefulWidget {
  const new({required this.onCreate, this.workspaceName});

  /// Name of the current workspace; `null` offers only the Global scope.
  final String? workspaceName;

  final Future<Result<_CreatedWorkflow>> Function(
    String name,
    String description,
    bool global,
  )
  onCreate;

  @override
  State<_CreateWorkflowDialog> createState() => _CreateWorkflowDialogState();
}

class _CreateWorkflowDialogState extends State<_CreateWorkflowDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _nameError;
  bool _isSubmitting = false;
  bool _global = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = l10n.workflowsNameRequiredError;
      });
      return;
    }
    setState(() {
      _nameError = null;
      _isSubmitting = true;
    });
    final result = await widget.onCreate(
      name,
      _descriptionController.text,
      _global,
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (created) => Navigator.of(context).pop(created),
      onFailure: (failure) {
        setState(() {
          _nameError = WorkflowL10n.localizeFailure(l10n, failure);
          _isSubmitting = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    return HiveDialog(
      title: l10n.workflowsCreateTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HiveTextField(
            key: const Key('create_workflow_name_field'),
            label: l10n.workflowsNameLabel,
            hint: l10n.workflowsNameHint,
            errorText: _nameError,
            controller: _nameController,
            autofocus: true,
            onSubmitted: (_) => unawaited(_submit()),
          ),
          if (widget.workspaceName != null) ...<Widget>[
            SizedBox(height: spacing.space2),
            HiveSegmentedControl<bool>(
              segments: <HiveSegment<bool>>[
                HiveSegment<bool>(value: false, label: widget.workspaceName!),
                HiveSegment<bool>(
                  value: true,
                  label: l10n.workflowsScopeGlobalBadge,
                ),
              ],
              selected: _global,
              onChanged: (global) => setState(() => _global = global),
              semanticLabel: l10n.workflowsScopeControlLabel,
            ),
          ],
          SizedBox(height: spacing.space2),
          HiveTextField(
            key: const Key('create_workflow_description_field'),
            label: l10n.workflowsDescriptionLabel,
            hint: l10n.workflowsDescriptionHint,
            controller: _descriptionController,
            multiline: true,
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
      actions: <Widget>[
        HiveButton(
          label: l10n.workflowsCancelAction,
          variant: HiveButtonVariant.secondary,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        HiveButton(
          key: const Key('create_workflow_confirm_button'),
          label: l10n.workflowsCreateConfirm,
          loading: _isSubmitting,
          onPressed: _isSubmitting ? null : () => unawaited(_submit()),
        ),
      ],
    );
  }
}
