import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Modal dialog for configuring and starting a new workflow [Run].
///
/// Returns the created [Run] on success, or `null` when dismissed.
class StartRunDialog extends ConsumerStatefulWidget {
  /// Creates a [StartRunDialog].
  const new({
    this.initialWorkflowId,
    this.initialWorkspaceId,
    this.initialWorktreeId,
    this.initialWorkspacePath,
    super.key,
  });

  /// Optional workflow ID to pre-select (for example when launched from a
  /// workflow card or the workflow editor).
  final String? initialWorkflowId;

  /// Optional workspace ID to pre-select (for example when launched from the
  /// side rail tree).
  final String? initialWorkspaceId;

  /// Optional worktree ID to pre-select (`primary` or a worktree ID).
  final String? initialWorktreeId;

  /// Optional workspace or worktree folder path to pre-fill.
  final String? initialWorkspacePath;

  /// Shows the [StartRunDialog] and returns the created [Run], or `null` if
  /// cancelled.
  static Future<Run?> show(
    BuildContext context, {
    String? initialWorkflowId,
    String? initialWorkspaceId,
    String? initialWorktreeId,
    String? initialWorkspacePath,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return HiveDialog.show<Run>(
      context: context,
      barrierLabel: l10n.runsCancelAction,
      builder: (_) => StartRunDialog(
        initialWorkflowId: initialWorkflowId,
        initialWorkspaceId: initialWorkspaceId,
        initialWorktreeId: initialWorktreeId,
        initialWorkspacePath: initialWorkspacePath,
      ),
    );
  }

  @override
  ConsumerState<StartRunDialog> createState() => _StartRunDialogState();
}

class _StartRunDialogState extends ConsumerState<StartRunDialog> {
  final TextEditingController _workspaceController = TextEditingController();

  List<WorkflowSummary> _workflows = const <WorkflowSummary>[];
  bool _isLoadingInitial = true;
  bool _isCheckingCapabilities = false;
  bool _isSubmitting = false;

  String? _selectedWorkflowId;
  WorkspaceIsolationMode _isolationMode = WorkspaceIsolationMode.direct;
  WorkspaceCapabilities? _capabilities;

  String? _workflowError;
  String? _workspaceError;
  String? _submitError;

  int _capabilitiesToken = 0;

  bool get _worktreeAvailable =>
      _capabilities != null &&
      _capabilities!.gitAvailable &&
      _capabilities!.isGitRepo &&
      _capabilities!.hasCommits;

  @override
  void initState() {
    super.initState();
    _selectedWorkflowId = widget.initialWorkflowId;
    final initialPath = widget.initialWorkspacePath;
    if (initialPath != null && initialPath.isNotEmpty) {
      _workspaceController.text = initialPath;
    }
    final initialWorktreeId = widget.initialWorktreeId;
    if (initialWorktreeId != null && initialWorktreeId != 'primary') {
      _isolationMode = WorkspaceIsolationMode.worktree;
    }
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final workflowsFuture = ref.read(listWorkflowsProvider).call();
    final settingsFuture = ref.read(getSettingsProvider).call();

    final workflowsResult = await workflowsFuture;
    final settingsResult = await settingsFuture;
    if (!mounted) return;

    final workflows = workflowsResult.valueOrNull ?? const <WorkflowSummary>[];
    var selectedId = _selectedWorkflowId;
    if (selectedId == null || !workflows.any((w) => w.id == selectedId)) {
      selectedId = workflows.isNotEmpty ? workflows.first.id : null;
    }

    final defaultWorkspace =
        settingsResult.valueOrNull?.defaultWorkspaceDir ?? '';
    if (_workspaceController.text.isEmpty && defaultWorkspace.isNotEmpty) {
      _workspaceController.text = defaultWorkspace;
    }

    setState(() {
      _workflows = workflows;
      _selectedWorkflowId = selectedId;
      _isLoadingInitial = false;
    });

    final path = _workspaceController.text.trim();
    if (path.isNotEmpty) {
      await _checkCapabilities(path);
    }
  }

  Future<void> _checkCapabilities(String rawPath) async {
    final path = rawPath.trim();
    final token = ++_capabilitiesToken;
    if (path.isEmpty) {
      setState(() {
        _capabilities = null;
        _isCheckingCapabilities = false;
        _isolationMode = WorkspaceIsolationMode.direct;
      });
      return;
    }

    setState(() => _isCheckingCapabilities = true);
    final result = await ref
        .read(getWorkspaceCapabilitiesProvider)
        .call(path: path);
    if (!mounted || token != _capabilitiesToken) return;

    final caps = result.valueOrNull;
    final canWorktree =
        caps != null && caps.gitAvailable && caps.isGitRepo && caps.hasCommits;

    setState(() {
      _capabilities = caps;
      _isCheckingCapabilities = false;
      if (!canWorktree && _isolationMode == WorkspaceIsolationMode.worktree) {
        _isolationMode = WorkspaceIsolationMode.direct;
      }
    });
  }

  Future<void> _browseWorkspace() async {
    final initial = _workspaceController.text.trim();
    final selectedPath = await ref
        .read(pickDirectoryProvider)
        .call(initialDirectory: initial.isEmpty ? null : initial);
    if (!mounted) return;

    if (selectedPath != null && selectedPath.isNotEmpty) {
      _workspaceController.text = selectedPath;
      setState(() {
        _workspaceError = null;
        _submitError = null;
      });
      await _checkCapabilities(selectedPath);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final workflowId = _selectedWorkflowId;
    final workspacePath = _workspaceController.text.trim();

    String? workflowError;
    String? workspaceError;
    if (workflowId == null || workflowId.isEmpty) {
      workflowError = l10n.startRunValidationWorkflowRequired;
    }
    if (workspacePath.isEmpty) {
      workspaceError = l10n.startRunValidationWorkspaceRequired;
    }
    if (workflowError != null || workspaceError != null) {
      setState(() {
        _workflowError = workflowError;
        _workspaceError = workspaceError;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _workflowError = null;
      _workspaceError = null;
      _submitError = null;
    });

    final result = await ref
        .read(startRunProvider)
        .call(
          StartRunRequest(
            workflowId: workflowId!,
            workspacePath: workspacePath,
            workspaceIsolationMode: _isolationMode,
          ),
        );
    if (!mounted) return;

    switch (result) {
      case Success<Run>(:final value):
        Navigator.of(context).pop(value);
      case FailureResult<Run>(:final failure):
        setState(() {
          _isSubmitting = false;
          _submitError = RunL10n.isConflict(failure)
              ? l10n.startRunConflictError
              : RunL10n.localizeFailure(l10n, failure);
        });
    }
  }

  String _worktreeHelperText(AppLocalizations l10n) {
    if (_isCheckingCapabilities) return l10n.startRunCheckingCapabilities;
    final caps = _capabilities;
    if (caps == null) return l10n.startRunIsolationDirectDescription;
    if (!caps.gitAvailable) return l10n.startRunWorktreeUnavailableNoGit;
    if (!caps.isGitRepo || !caps.hasCommits) {
      return l10n.startRunWorktreeUnavailableNotRepo;
    }
    return _isolationMode == WorkspaceIsolationMode.worktree
        ? l10n.startRunIsolationWorktreeDescription
        : l10n.startRunIsolationDirectDescription;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;

    final workflowOptions = <HiveSelectOption<String>>[
      for (final workflow in _workflows)
        HiveSelectOption<String>(value: workflow.id, label: workflow.name),
    ];

    return HiveDialog(
      title: l10n.startRunDialogTitle,
      icon: HiveIcons.runs,
      content: _isLoadingInitial
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.space4),
                child: HiveSpinner(size: spacing.space4, color: colors.accent),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_workflows.isEmpty)
                  HiveBanner(
                    tone: HiveFeedbackTone.warning,
                    title: l10n.startRunNoWorkflowsMessage,
                  )
                else
                  HiveSelect<String>(
                    key: const Key('start_run_workflow_select'),
                    label: l10n.startRunWorkflowLabel,
                    hint: l10n.startRunWorkflowPlaceholder,
                    options: workflowOptions,
                    value: _selectedWorkflowId,
                    errorText: _workflowError,
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() {
                            _selectedWorkflowId = value;
                            _workflowError = null;
                            _submitError = null;
                          }),
                  ),
                SizedBox(height: spacing.space3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: HiveTextField(
                        key: const Key('start_run_workspace_field'),
                        label: l10n.startRunWorkspaceLabel,
                        hint: l10n.startRunWorkspaceHint,
                        controller: _workspaceController,
                        errorText: _workspaceError,
                        enabled: !_isSubmitting,
                        onChanged: (value) {
                          setState(() {
                            _workspaceError = null;
                            _submitError = null;
                          });
                          unawaited(_checkCapabilities(value));
                        },
                      ),
                    ),
                    SizedBox(width: spacing.space2),
                    HiveButton(
                      key: const Key('start_run_browse_button'),
                      label: l10n.startRunBrowseAction,
                      icon: HiveIcons.folder,
                      variant: HiveButtonVariant.secondary,
                      onPressed: _isSubmitting
                          ? null
                          : () => unawaited(_browseWorkspace()),
                    ),
                  ],
                ),
                SizedBox(height: spacing.space3),
                Text(
                  l10n.startRunIsolationLabel,
                  style: typography.label.copyWith(color: colors.onSurface),
                ),
                SizedBox(height: spacing.space1),
                Wrap(
                  spacing: spacing.space2,
                  runSpacing: spacing.space1,
                  children: <Widget>[
                    HiveFilterChip(
                      key: const Key('start_run_isolation_direct'),
                      label: l10n.startRunIsolationDirect,
                      selected: _isolationMode == WorkspaceIsolationMode.direct,
                      onSelected: _isSubmitting
                          ? null
                          : (_) => setState(() {
                              _isolationMode = WorkspaceIsolationMode.direct;
                              _submitError = null;
                            }),
                    ),
                    HiveFilterChip(
                      key: const Key('start_run_isolation_worktree'),
                      label: l10n.startRunIsolationWorktree,
                      selected:
                          _isolationMode == WorkspaceIsolationMode.worktree,
                      onSelected: (!_isSubmitting && _worktreeAvailable)
                          ? (_) => setState(() {
                              _isolationMode = WorkspaceIsolationMode.worktree;
                              _submitError = null;
                            })
                          : null,
                    ),
                  ],
                ),
                SizedBox(height: spacing.space1),
                Text(
                  _worktreeHelperText(l10n),
                  style: typography.bodySmall.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
                if (_submitError != null) ...<Widget>[
                  SizedBox(height: spacing.space3),
                  HiveBanner(
                    key: const Key('start_run_error_banner'),
                    tone: HiveFeedbackTone.danger,
                    title: _submitError!,
                    liveRegion: true,
                  ),
                ],
              ],
            ),
      actions: <Widget>[
        HiveButton(
          key: const Key('start_run_cancel_button'),
          label: l10n.runsCancelAction,
          variant: HiveButtonVariant.secondary,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        HiveButton(
          key: const Key('start_run_confirm_button'),
          label: _isSubmitting
              ? l10n.startRunStartingAction
              : l10n.startRunConfirmAction,
          icon: HiveIcons.play,
          loading: _isSubmitting,
          onPressed: (_isLoadingInitial || _isSubmitting || _workflows.isEmpty)
              ? null
              : () => unawaited(_submit()),
        ),
      ],
    );
  }
}
