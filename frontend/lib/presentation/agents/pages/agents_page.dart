import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_controller.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_migration_controller.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_state.dart';
import 'package:agentic_hive_frontend/presentation/agents/widgets/agent_detail_pane.dart';
import 'package:agentic_hive_frontend/presentation/agents/widgets/agent_list_pane.dart';
import 'package:agentic_hive_frontend/presentation/agents/widgets/agents_migration_banner.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Master-detail library page for browsing, creating, editing, and deleting
/// reusable Agent `.md` files.
class AgentsPage extends ConsumerWidget {
  /// Creates an [AgentsPage].
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final state = ref.watch(agentsControllerProvider);
    final controller = ref.read(agentsControllerProvider.notifier);
    final migration = ref.watch(agentsMigrationControllerProvider).value;
    final currentWorkspace = ref
        .watch(workspaceRegistryControllerProvider)
        .value
        ?.currentWorkspace;

    Future<void> handleSave() async {
      final outcome = await controller.save();
      if (!context.mounted) return;
      switch (outcome) {
        case SaveAgentSuccess(:final created):
          HiveToast.show(
            context,
            tone: HiveToastTone.success,
            message: created
                ? l10n.agentsCreateSuccess
                : l10n.agentsSaveSuccess,
          );
        case SaveAgentConflict():
          final agentId = state.draft?.id ?? '';
          final choice = await showHiveConfirmDialog(
            context,
            title: l10n.agentsConflictDialogTitle,
            message: l10n.agentsConflictDialogMessage(agentId),
            confirmLabel: l10n.agentsOverwriteAction,
            secondaryLabel: l10n.agentsReloadAction,
            cancelLabel: l10n.agentsCancelAction,
            tone: HiveConfirmTone.destructive,
            icon: HiveIcons.alert,
          );
          if (!context.mounted) return;
          switch (choice) {
            case HiveConfirmChoice.secondary:
              await controller.reloadSelected();
            case HiveConfirmChoice.confirm:
              final overwriteOutcome = await controller.forceOverwrite();
              if (!context.mounted) return;
              if (overwriteOutcome is SaveAgentSuccess) {
                HiveToast.show(
                  context,
                  tone: HiveToastTone.success,
                  message: l10n.agentsSaveSuccess,
                );
              }
            case HiveConfirmChoice.cancel:
              break;
          }
        case SaveAgentFailure():
          break;
      }
    }

    Future<void> handleDelete() async {
      final draft = state.draft;
      if (draft == null) return;
      final displayName = draft.name.trim().isEmpty ? draft.id : draft.name;
      final choice = await showHiveConfirmDialog(
        context,
        title: l10n.agentsDeleteDialogTitle,
        message: l10n.agentsDeleteDialogMessage(displayName, draft.id),
        confirmLabel: l10n.agentsDeleteAction,
        cancelLabel: l10n.agentsCancelAction,
        tone: HiveConfirmTone.destructive,
        icon: HiveIcons.delete,
      );
      if (choice != HiveConfirmChoice.confirm || !context.mounted) return;
      final result = await controller.deleteSelected();
      if (!context.mounted) return;
      if (result is Success<void>) {
        HiveToast.show(
          context,
          tone: HiveToastTone.success,
          message: l10n.agentsDeleteSuccess,
        );
      }
    }

    return Padding(
      padding: EdgeInsets.all(spacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivePageHeader(
            title: l10n.navAgents,
            actions: <Widget>[
              if (currentWorkspace != null)
                HiveSegmentedControl<bool>(
                  segments: <HiveSegment<bool>>[
                    HiveSegment<bool>(
                      value: false,
                      label: currentWorkspace.name,
                    ),
                    HiveSegment<bool>(
                      value: true,
                      label: l10n.agentsScopeGlobalOption,
                    ),
                  ],
                  selected: state.globalOnly,
                  onChanged: (globalOnly) =>
                      unawaited(controller.setGlobalOnly(globalOnly)),
                  semanticLabel: l10n.agentsScopeControlLabel,
                ),
              HiveButton(
                label: l10n.agentsNewAction,
                icon: HiveIcons.add,
                onPressed: controller.startCreate,
              ),
            ],
          ),
          if (migration != null && migration.hasPendingConflicts) ...<Widget>[
            AgentsMigrationBanner(
              status: migration,
              onDismiss: () => unawaited(
                ref.read(agentsMigrationControllerProvider.notifier).dismiss(),
              ),
            ),
            SizedBox(height: spacing.space3),
          ],
          Expanded(
            child: HiveMasterDetail(
              detailVisible: state.hasDetailOpen,
              master: AgentListPane(
                state: state,
                onSearchChanged: controller.setSearchQuery,
                onToggleTag: controller.toggleTagFilter,
                onSelectAgent: (agent) => unawaited(
                  controller.selectAgent(agent.id, scope: agent.scope),
                ),
                onCreate: controller.startCreate,
                onRetry: controller.loadAgents,
              ),
              detail: AgentDetailPane(
                state: state,
                onNameChanged: controller.updateName,
                onSlugChanged: controller.updateSlug,
                onDescriptionChanged: controller.updateDescription,
                onPromptChanged: controller.updatePrompt,
                onAddTag: controller.addTag,
                onRemoveTag: controller.removeTag,
                onAddRequiredSkill: controller.addRequiredSkill,
                onRemoveRequiredSkill: controller.removeRequiredSkill,
                onAddRequiredTool: controller.addRequiredTool,
                onRemoveRequiredTool: controller.removeRequiredTool,
                onAddAllowedTool: controller.addAllowedTool,
                onRemoveAllowedTool: controller.removeAllowedTool,
                onAddDeniedTool: controller.addDeniedTool,
                onRemoveDeniedTool: controller.removeDeniedTool,
                onInsertTemplate: () =>
                    controller.insertTemplate(l10n.agentsStarterTemplate),
                onPreviewModeChanged: controller.setPreviewMode,
                onSave: handleSave,
                onDelete: handleDelete,
                onReload: controller.reloadSelected,
                onDismissExternalNotice: controller.dismissExternalNotice,
                onDismissSaveError: controller.dismissSaveError,
                onBackToList: controller.clearSelection,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
