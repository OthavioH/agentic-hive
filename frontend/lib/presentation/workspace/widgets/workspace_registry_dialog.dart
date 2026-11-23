import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/workspace_settings_dialog.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Wireframe dialog for listing, adding, renaming, and unregistering
/// workspaces.
class WorkspaceRegistryDialog extends ConsumerStatefulWidget {
  /// Creates a [WorkspaceRegistryDialog].
  const new({super.key});

  /// Shows the [WorkspaceRegistryDialog] using [HiveDialog.show].
  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HiveDialog.show<void>(
      context: context,
      barrierLabel: l10n.dialogDismissLabel,
      builder: (_) => const WorkspaceRegistryDialog(),
    );
  }

  @override
  ConsumerState<WorkspaceRegistryDialog> createState() =>
      _WorkspaceRegistryDialogState();
}

class _WorkspaceRegistryDialogState
    extends ConsumerState<WorkspaceRegistryDialog> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _nameManuallyEdited = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pathController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onPathChanged(String value) {
    if (!_nameManuallyEdited) {
      final trimmed = value.trim();
      final defaultName = trimmed.isEmpty ? '' : p.basename(trimmed);
      _nameController.text = defaultName;
    }
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _onNameChanged(String value) {
    _nameManuallyEdited = value.trim().isNotEmpty;
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _browseFolder() async {
    final picked = await ref
        .read(workspaceRegistryControllerProvider.notifier)
        .pickWorkspaceFolder();
    if (!mounted || picked == null || picked.trim().isEmpty) return;
    _pathController.text = picked;
    _nameManuallyEdited = false;
    _onPathChanged(picked);
  }

  Future<void> _addWorkspace(AppLocalizations l10n) async {
    final rootPath = _pathController.text.trim();
    if (rootPath.isEmpty) {
      setState(() => _errorMessage = l10n.workspaceErrorPathRequired);
      return;
    }
    final nameText = _nameController.text.trim();
    final result = await ref
        .read(workspaceRegistryControllerProvider.notifier)
        .addWorkspace(
          rootPath: rootPath,
          name: nameText.isEmpty ? null : nameText,
        );
    if (!mounted) return;
    switch (result) {
      case Success<Workspace>():
        _pathController.clear();
        _nameController.clear();
        _nameManuallyEdited = false;
        setState(() => _errorMessage = null);
      case FailureResult<Workspace>(:final failure):
        setState(() => _errorMessage = _localizeFailure(failure, l10n));
    }
  }

  Future<void> _renameWorkspace(
    Workspace workspace,
    AppLocalizations l10n,
  ) async {
    final newName = await HiveDialog.show<String>(
      context: context,
      barrierLabel: l10n.dialogDismissLabel,
      builder: (_) => _RenameWorkspaceDialog(initialName: workspace.name),
    );
    if (!mounted || newName == null || newName == workspace.name) return;

    final result = await ref
        .read(workspaceRegistryControllerProvider.notifier)
        .renameWorkspace(workspace.id, name: newName);
    if (!mounted) return;
    if (result case FailureResult<Workspace>(:final failure)) {
      setState(() => _errorMessage = _localizeFailure(failure, l10n));
    }
  }

  Future<void> _removeWorkspace(
    Workspace workspace,
    AppLocalizations l10n,
  ) async {
    final message = workspace.activeRunCount > 0
        ? l10n.workspaceRemoveActiveRunsMessage(
            workspace.name,
            workspace.activeRunCount,
          )
        : l10n.workspaceRemoveMessage(workspace.name);

    final choice = await showHiveConfirmDialog(
      context,
      title: l10n.workspaceRemoveTitle,
      message: message,
      confirmLabel: l10n.workspaceRemoveConfirm,
      cancelLabel: l10n.workspaceRemoveCancel,
      tone: HiveConfirmTone.destructive,
      icon: HiveIcons.alert,
    );
    if (!mounted || choice != HiveConfirmChoice.confirm) return;

    final result = await ref
        .read(workspaceRegistryControllerProvider.notifier)
        .removeWorkspace(workspace.id);
    if (!mounted) return;
    if (result case FailureResult<void>(:final failure)) {
      setState(() => _errorMessage = _localizeFailure(failure, l10n));
    }
  }

  String _localizeFailure(Failure failure, AppLocalizations l10n) =>
      switch (failure) {
        NetworkFailure() => l10n.workspaceErrorNetwork,
        ConflictFailure() => l10n.workspaceErrorConflict,
        BackendFailure(:final statusCode, :final message)
            when statusCode == 409 =>
          message.isNotEmpty ? message : l10n.workspaceErrorConflict,
        BackendFailure(:final message) when message.isNotEmpty => message,
        ValidationFailure(:final message) when message.isNotEmpty => message,
        _ => l10n.workspaceErrorUnexpected,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final asyncState = ref.watch(workspaceRegistryControllerProvider);
    final isSubmitting = asyncState.asData?.value.isSubmitting ?? false;

    return HiveDialog(
      title: l10n.workspaceRegistryTitle,
      message: l10n.workspaceRegistrySubtitle,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: spacing.space8 * 8,
          maxHeight: spacing.space8 * 6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_errorMessage case final errorMessage?) ...<Widget>[
                HiveBanner(
                  tone: HiveFeedbackTone.danger,
                  title: l10n.workspaceLoadError,
                  message: errorMessage,
                  onDismiss: () => setState(() => _errorMessage = null),
                  dismissSemanticLabel: l10n.overviewDismissAction,
                ),
                SizedBox(height: spacing.space2),
              ],
              switch (asyncState) {
                AsyncLoading<WorkspaceRegistryState>() => Center(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.space3),
                    child: HiveSpinner(
                      size: spacing.space3,
                      color: colors.accent,
                    ),
                  ),
                ),
                AsyncError<WorkspaceRegistryState>() => HiveEmptyState(
                  icon: HiveIcons.alert,
                  title: l10n.workspaceLoadError,
                  message: l10n.workspaceErrorNetwork,
                  action: HiveButton(
                    label: l10n.workspaceRetryAction,
                    icon: HiveIcons.refresh,
                    onPressed: () => unawaited(
                      ref
                          .read(workspaceRegistryControllerProvider.notifier)
                          .refresh(),
                    ),
                  ),
                ),
                AsyncData<WorkspaceRegistryState>(:final value) =>
                  value.workspaces.isEmpty
                      ? HiveEmptyState(
                          icon: HiveIcons.folder,
                          title: l10n.workspaceEmptyTitle,
                          message: l10n.workspaceEmptyMessage,
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: spacing.space8 * 4,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: value.workspaces.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: spacing.space1),
                            itemBuilder: (context, index) {
                              final workspace = value.workspaces[index];
                              final activeRunsLabel = l10n
                                  .workspaceActiveRunsBadge(
                                    workspace.activeRunCount,
                                  );
                              return HiveCard(
                                child: Row(
                                  children: <Widget>[
                                    HiveIcon(
                                      HiveIcons.folder,
                                      size: spacing.space2,
                                      color: colors.onSurfaceMuted,
                                    ),
                                    SizedBox(width: spacing.space2),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            workspace.name,
                                            style: typography.titleSmall
                                                .copyWith(
                                                  color: colors.onSurface,
                                                ),
                                          ),
                                          Text(
                                            workspace.rootPath,
                                            style: typography.bodySmall
                                                .copyWith(
                                                  color: colors.onSurfaceMuted,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (workspace.isGit ||
                                              workspace.activeRunCount > 0)
                                            Wrap(
                                              spacing: spacing.space1,
                                              children: <Widget>[
                                                if (workspace.isGit)
                                                  HiveBadge(
                                                    label:
                                                        l10n.workspaceGitBadge,
                                                  ),
                                                if (workspace.activeRunCount >
                                                    0)
                                                  HiveBadge(
                                                    label: activeRunsLabel,
                                                  ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: spacing.space1),
                                    HiveIconButton(
                                      key: Key(
                                        'workspace_settings_button_'
                                        '${workspace.id}',
                                      ),
                                      icon: HiveIcons.settings,
                                      semanticLabel: l10n
                                          .workspaceSettingsTooltip(
                                            workspace.name,
                                          ),
                                      onPressed: () => unawaited(
                                        WorkspaceSettingsDialog.show(
                                          context,
                                          workspace,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: spacing.space1),
                                    HiveIconButton(
                                      key: Key(
                                        'workspace_rename_button_'
                                        '${workspace.id}',
                                      ),
                                      icon: HiveIcons.edit,
                                      semanticLabel: l10n
                                          .workspaceRenameTooltip(
                                            workspace.name,
                                          ),
                                      onPressed: isSubmitting
                                          ? null
                                          : () => unawaited(
                                              _renameWorkspace(workspace, l10n),
                                            ),
                                    ),
                                    SizedBox(width: spacing.space1),
                                    HiveIconButton(
                                      key: Key(
                                        'workspace_remove_button_'
                                        '${workspace.id}',
                                      ),
                                      icon: HiveIcons.delete,
                                      semanticLabel: l10n
                                          .workspaceRemoveTooltip(
                                            workspace.name,
                                          ),
                                      onPressed: isSubmitting
                                          ? null
                                          : () => unawaited(
                                              _removeWorkspace(workspace, l10n),
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
              },
              SizedBox(height: spacing.space3),
              HiveTextField(
                key: const Key('workspace_add_path_field'),
                label: l10n.workspaceAddFolderLabel,
                hintText: l10n.workspaceAddFolderHint,
                controller: _pathController,
                enabled: !isSubmitting,
                onChanged: _onPathChanged,
                trailing: HiveButton(
                  key: const Key('workspace_add_browse_button'),
                  label: l10n.workspaceAddBrowseAction,
                  icon: HiveIcons.folder,
                  variant: HiveButtonVariant.ghost,
                  size: HiveButtonSize.small,
                  onPressed: isSubmitting
                      ? null
                      : () => unawaited(_browseFolder()),
                ),
              ),
              SizedBox(height: spacing.space2),
              HiveTextField(
                key: const Key('workspace_add_name_field'),
                label: l10n.workspaceAddNameLabel,
                hintText: l10n.workspaceAddNameHint,
                controller: _nameController,
                enabled: !isSubmitting,
                onChanged: _onNameChanged,
              ),
              SizedBox(height: spacing.space2),
              Align(
                alignment: Alignment.centerRight,
                child: HiveButton(
                  key: const Key('workspace_add_submit_button'),
                  label: l10n.workspaceAddAction,
                  icon: HiveIcons.add,
                  loading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () => unawaited(_addWorkspace(l10n)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        HiveButton(
          label: l10n.workspaceCloseAction,
          variant: HiveButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _RenameWorkspaceDialog extends StatefulWidget {
  const new({required this.initialName});

  final String initialName;

  @override
  State<_RenameWorkspaceDialog> createState() => _RenameWorkspaceDialogState();
}

class _RenameWorkspaceDialogState extends State<_RenameWorkspaceDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HiveDialog(
      title: l10n.workspaceRenameTitle,
      content: HiveTextField(
        key: const Key('workspace_rename_name_field'),
        label: l10n.workspaceAddNameLabel,
        controller: _controller,
        autofocus: true,
      ),
      actions: <Widget>[
        HiveButton(
          label: l10n.workspaceRenameCancel,
          variant: HiveButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        HiveButton(
          key: const Key('workspace_rename_save_button'),
          label: l10n.workspaceRenameSave,
          onPressed: () {
            final trimmed = _controller.text.trim();
            if (trimmed.isNotEmpty) {
              Navigator.of(context).pop(trimmed);
            }
          },
        ),
      ],
    );
  }
}
