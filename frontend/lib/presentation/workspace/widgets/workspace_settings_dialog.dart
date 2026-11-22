import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_settings_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Wireframe dialog that edits the per-workspace execution settings
/// overrides: default isolation mode, snapshot ignore patterns and default
/// shell. Anything left on inherit follows the global value.
class WorkspaceSettingsDialog extends ConsumerStatefulWidget {
  /// Creates a [WorkspaceSettingsDialog] for [workspace].
  const new({required this.workspace, super.key});

  /// The workspace whose overrides are edited.
  final Workspace workspace;

  /// Shows the dialog using [HiveDialog.show].
  static Future<void> show(BuildContext context, Workspace workspace) {
    final l10n = AppLocalizations.of(context)!;
    return HiveDialog.show<void>(
      context: context,
      barrierLabel: l10n.dialogDismissLabel,
      builder: (_) => WorkspaceSettingsDialog(workspace: workspace),
    );
  }

  @override
  ConsumerState<WorkspaceSettingsDialog> createState() =>
      _WorkspaceSettingsDialogState();
}

class _WorkspaceSettingsDialogState
    extends ConsumerState<WorkspaceSettingsDialog> {
  final TextEditingController _shellController = TextEditingController();
  bool _initialized = false;
  WorkspaceIsolationMode? _mode;
  bool _overridePatterns = false;
  List<String> _patterns = <String>[];
  String? _errorMessage;

  @override
  void dispose() {
    _shellController.dispose();
    super.dispose();
  }

  void _initialize(ExecutionSettings overrides, EffectiveExecutionSettings g) {
    _initialized = true;
    _mode = overrides.defaultIsolationMode;
    _overridePatterns = overrides.ignorePatterns != null;
    _patterns = List<String>.of(overrides.ignorePatterns ?? g.ignorePatterns);
    _shellController.text = overrides.defaultShell ?? '';
  }

  ExecutionSettings _collect() {
    final shell = _shellController.text.trim();
    return ExecutionSettings(
      defaultIsolationMode: _mode,
      ignorePatterns: _overridePatterns
          ? <String>[
              for (final pattern in _patterns)
                if (pattern.trim().isNotEmpty) pattern.trim(),
            ]
          : null,
      defaultShell: shell.isEmpty ? null : shell,
    );
  }

  Future<void> _save(AppLocalizations l10n) async {
    final result = await ref
        .read(workspaceSettingsControllerProvider(widget.workspace.id).notifier)
        .save(_collect());
    if (!mounted) return;
    switch (result) {
      case Success<WorkspaceSettingsResponse>():
        Navigator.of(context).pop();
      case FailureResult<WorkspaceSettingsResponse>(:final failure):
        setState(() => _errorMessage = _failureMessage(failure, l10n));
    }
  }

  String _failureMessage(Failure failure, AppLocalizations l10n) =>
      switch (failure) {
        ValidationFailure(:final message) when message.isNotEmpty => message,
        BackendFailure(:final message) when message.isNotEmpty => message,
        _ => l10n.workspaceSettingsSaveError,
      };

  String _modeName(WorkspaceIsolationMode mode, AppLocalizations l10n) =>
      switch (mode) {
        WorkspaceIsolationMode.direct => l10n.workspaceSettingsIsolationDirect,
        WorkspaceIsolationMode.worktree =>
          l10n.workspaceSettingsIsolationWorktree,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final asyncState = ref.watch(
      workspaceSettingsControllerProvider(widget.workspace.id),
    );
    final loaded = asyncState.asData?.value;
    if (loaded != null && !_initialized) {
      _initialize(loaded.response.overrides, loaded.response.global);
    }
    final isSaving = loaded?.isSaving ?? false;

    return HiveDialog(
      title: l10n.workspaceSettingsTitle(widget.workspace.name),
      message: l10n.workspaceSettingsSubtitle,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: spacing.space8 * 8,
          maxHeight: spacing.space8 * 7,
        ),
        child: switch (asyncState) {
          AsyncLoading<WorkspaceSettingsState>() => Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.space3),
              child: HiveSpinner(size: spacing.space3, color: colors.accent),
            ),
          ),
          AsyncError<WorkspaceSettingsState>() => HiveEmptyState(
            icon: HiveIcons.alert,
            title: l10n.workspaceSettingsLoadError,
            action: HiveButton(
              label: l10n.workspaceRetryAction,
              icon: HiveIcons.refresh,
              onPressed: () => ref.invalidate(
                workspaceSettingsControllerProvider(widget.workspace.id),
              ),
            ),
          ),
          AsyncData<WorkspaceSettingsState>(:final value) =>
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_errorMessage case final errorMessage?) ...<Widget>[
                    HiveBanner(
                      tone: HiveFeedbackTone.danger,
                      title: l10n.workspaceSettingsSaveError,
                      message: errorMessage,
                      onDismiss: () => setState(() => _errorMessage = null),
                      dismissSemanticLabel: l10n.overviewDismissAction,
                    ),
                    SizedBox(height: spacing.space2),
                  ],
                  Text(
                    l10n.workspaceSettingsIsolationLabel,
                    style: typography.labelMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  SizedBox(height: spacing.space1),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: HiveSegmentedControl<WorkspaceIsolationMode?>(
                      key: const Key('workspace_settings_isolation'),
                      semanticLabel: l10n.workspaceSettingsIsolationLabel,
                      selected: _mode,
                      onChanged: isSaving
                          ? null
                          : (mode) => setState(() => _mode = mode),
                      segments: <HiveSegment<WorkspaceIsolationMode?>>[
                        HiveSegment<WorkspaceIsolationMode?>(
                          value: null,
                          label: l10n.workspaceSettingsInheritOption,
                        ),
                        HiveSegment<WorkspaceIsolationMode?>(
                          value: WorkspaceIsolationMode.direct,
                          label: l10n.workspaceSettingsIsolationDirect,
                        ),
                        HiveSegment<WorkspaceIsolationMode?>(
                          value: WorkspaceIsolationMode.worktree,
                          label: l10n.workspaceSettingsIsolationWorktree,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.space1),
                  Text(
                    l10n.workspaceSettingsInheritedValue(
                      _modeName(
                        value.response.global.defaultIsolationMode,
                        l10n,
                      ),
                    ),
                    style: typography.bodySmall.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                  SizedBox(height: spacing.space3),
                  HiveSwitch(
                    key: const Key('workspace_settings_patterns_switch'),
                    label: l10n.workspaceSettingsPatternsOverrideLabel,
                    value: _overridePatterns,
                    onChanged: isSaving
                        ? null
                        : (enabled) =>
                              setState(() => _overridePatterns = enabled),
                  ),
                  SizedBox(height: spacing.space1),
                  if (_overridePatterns)
                    HiveStringListField(
                      key: const Key('workspace_settings_patterns'),
                      label: l10n.workspaceSettingsPatternsLabel,
                      items: _patterns,
                      itemLabel: l10n.workspaceSettingsPatternItemLabel,
                      itemPlaceholder: l10n.workspaceSettingsPatternPlaceholder,
                      addButtonLabel: l10n.workspaceSettingsPatternAdd,
                      removeButtonLabel: l10n.workspaceSettingsPatternRemove,
                      emptyText: l10n.workspaceSettingsPatternsEmpty,
                      enabled: !isSaving,
                      onChanged: (items) => _patterns = items,
                    )
                  else
                    Text(
                      l10n.workspaceSettingsPatternsInherited(
                        value.response.global.ignorePatterns.isEmpty
                            ? l10n.workspaceSettingsPatternsNone
                            : value.response.global.ignorePatterns.join(', '),
                      ),
                      style: typography.bodySmall.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  SizedBox(height: spacing.space3),
                  HiveTextField(
                    key: const Key('workspace_settings_shell_field'),
                    label: l10n.workspaceSettingsShellLabel,
                    hintText: l10n.workspaceSettingsShellHint(
                      value.response.global.defaultShell,
                    ),
                    controller: _shellController,
                    enabled: !isSaving,
                  ),
                  SizedBox(height: spacing.space3),
                  Text(
                    l10n.workspaceSettingsMachineNote,
                    style: typography.bodySmall.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
        },
      ),
      actions: <Widget>[
        HiveButton(
          label: l10n.workspaceCloseAction,
          variant: HiveButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        HiveButton(
          key: const Key('workspace_settings_save_button'),
          label: l10n.workspaceSettingsSaveAction,
          loading: isSaving,
          onPressed: (loaded == null || isSaving)
              ? null
              : () => unawaited(_save(l10n)),
        ),
      ],
    );
  }
}
