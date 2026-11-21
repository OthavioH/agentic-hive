import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflows_list_controller.dart';
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
    final created = await HiveDialog.show<Workflow>(
      context: context,
      barrierLabel: l10n.workflowsCancelAction,
      builder: (dialogContext) => _CreateWorkflowDialog(
        onCreate: (name, description) => ref
            .read(workflowsListControllerProvider.notifier)
            .createWorkflow(name: name, description: description),
      ),
    );

    if (created != null && context.mounted) {
      WorkflowEditorRoute(id: created.id).go(context);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WorkflowSummary workflow,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await HiveDialog.confirm(
      context: context,
      title: l10n.workflowsDeleteTitle,
      message: l10n.workflowsDeleteMessage(workflow.name),
      confirmLabel: l10n.workflowsDeleteConfirm,
      cancelLabel: l10n.workflowsCancelAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(workflowsListControllerProvider.notifier)
        .deleteWorkflow(workflow.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final stateAsync = ref.watch(workflowsListControllerProvider);

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
            Expanded(
              child: stateAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => HiveEmptyState(
                  icon: HiveIcons.alert,
                  title: l10n.workflowsLoadErrorTitle,
                  message: error.toString(),
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
                      if (listState.actionError != null) ...<Widget>[
                        SizedBox(height: spacing.space2),
                        HiveBadge(
                          label: listState.actionError!,
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
                                  final isBusy =
                                      listState.busyWorkflowId == summary.id;
                                  final formattedDate = DateFormat.yMMMd()
                                      .add_Hm()
                                      .format(summary.updatedAt.toLocal());
                                  final hasErrors = summary.hasValidationErrors;
                                  final statusLabel = hasErrors
                                      ? l10n.workflowsStatusInvalid
                                      : l10n.workflowsStatusValid;
                                  final statusTone = hasErrors
                                      ? HiveBadgeTone.danger
                                      : HiveBadgeTone.success;

                                  return HiveCard(
                                    key: Key('workflow_card_${summary.id}'),
                                    surface: HiveCardSurface.surface2,
                                    semanticLabel: l10n.workflowsOpenAction(
                                      summary.name,
                                    ),
                                    onPressed: isBusy
                                        ? null
                                        : () => WorkflowEditorRoute(
                                            id: summary.id,
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
                                                ],
                                              ),
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
                                            'duplicate_workflow_${summary.id}',
                                          ),
                                          icon: HiveIcons.copy,
                                          semanticLabel:
                                              l10n.workflowsDuplicateAction,
                                          onPressed: isBusy
                                              ? null
                                              : () => unawaited(
                                                  controller.duplicateWorkflow(
                                                    summary.id,
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

class _CreateWorkflowDialog extends StatefulWidget {
  const new({required this.onCreate});

  final Future<Result<Workflow>> Function(String name, String description)
  onCreate;

  @override
  State<_CreateWorkflowDialog> createState() => _CreateWorkflowDialogState();
}

class _CreateWorkflowDialogState extends State<_CreateWorkflowDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _nameError;
  bool _isSubmitting = false;

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
    final result = await widget.onCreate(name, _descriptionController.text);
    if (!mounted) return;
    result.fold(
      onSuccess: (workflow) => Navigator.of(context).pop(workflow),
      onFailure: (failure) {
        setState(() {
          _nameError = failure.message;
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
