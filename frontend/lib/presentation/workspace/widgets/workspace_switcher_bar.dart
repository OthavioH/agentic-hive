import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/workspace_registry_dialog.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Compact wireframe bar displaying the current workspace and opening the
/// workspace registry dialog.
class WorkspaceSwitcherBar extends ConsumerWidget {
  /// Creates a [WorkspaceSwitcherBar].
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final asyncState = ref.watch(workspaceRegistryControllerProvider);

    return HiveCard(
      child: Row(
        children: <Widget>[
          HiveIcon(
            HiveIcons.folder,
            size: spacing.space2,
            color: colors.onSurfaceMuted,
          ),
          SizedBox(width: spacing.space1),
          Expanded(
            child: switch (asyncState) {
              AsyncLoading<WorkspaceRegistryState>() => Text(
                l10n.workspaceLoading,
                style: typography.bodySmall.copyWith(
                  color: colors.onSurfaceMuted,
                ),
              ),
              AsyncError<WorkspaceRegistryState>() => Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.workspaceLoadError,
                      style: typography.bodySmall.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ),
                  HiveButton(
                    label: l10n.workspaceRetryAction,
                    variant: HiveButtonVariant.ghost,
                    size: HiveButtonSize.small,
                    onPressed: () => unawaited(
                      ref
                          .read(workspaceRegistryControllerProvider.notifier)
                          .refresh(),
                    ),
                  ),
                ],
              ),
              AsyncData<WorkspaceRegistryState>(:final value) =>
                value.workspaces.isEmpty
                    ? Text(
                        l10n.workspaceNoneSelected,
                        style: typography.bodySmall.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: spacing.space8 * 5,
                        ),
                        child: HiveSelect<String>(
                          key: const Key('workspace_switcher_select'),
                          label: l10n.workspaceCurrentLabel,
                          value: value.currentWorkspaceId,
                          options: <HiveSelectOption<String>>[
                            for (final workspace in value.workspaces)
                              HiveSelectOption<String>(
                                value: workspace.id,
                                label: workspace.name,
                                icon: HiveIcons.folder,
                              ),
                          ],
                          onChanged: (id) => unawaited(
                            ref
                                .read(
                                  workspaceRegistryControllerProvider.notifier,
                                )
                                .selectWorkspace(id),
                          ),
                        ),
                      ),
            },
          ),
          SizedBox(width: spacing.space2),
          HiveButton(
            key: const Key('workspace_manage_button'),
            label: l10n.workspaceManageAction,
            variant: HiveButtonVariant.secondary,
            size: HiveButtonSize.small,
            onPressed: () => unawaited(WorkspaceRegistryDialog.show(context)),
          ),
        ],
      ),
    );
  }
}
