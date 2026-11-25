import 'dart:async';

import 'package:agentic_hive_frontend/core/attachments/attachment_input_source.dart';
import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/run_attachment_drafts.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  /// Shows the [StartRunDialog] and returns the created [Run], or `null` if
  /// cancelled.
  static Future<Run?> show(
    BuildContext context, {
    String? initialWorkflowId,
    String? initialWorkspaceId,
    String? initialWorktreeId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return HiveDialog.show<Run>(
      context: context,
      barrierLabel: l10n.runsCancelAction,
      builder: (_) => StartRunDialog(
        initialWorkflowId: initialWorkflowId,
        initialWorkspaceId: initialWorkspaceId,
        initialWorktreeId: initialWorktreeId,
      ),
    );
  }

  @override
  ConsumerState<StartRunDialog> createState() => _StartRunDialogState();
}

enum _RunTargetKind { primary, existingWorktree, newWorktree }

class _PasteIntent extends Intent {
  const new();
}

class _StartRunDialogState extends ConsumerState<StartRunDialog> {
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  List<WorkflowSummary> _workflows = const <WorkflowSummary>[];
  List<Workspace> _workspaces = const <Workspace>[];
  List<Worktree> _worktrees = const <Worktree>[];
  bool _isLoadingInitial = true;
  bool _isCheckingCapabilities = false;
  bool _isSubmitting = false;
  bool _appliedInitialWorktree = false;

  String? _selectedWorkflowId;
  String? _selectedWorkspaceId;
  _RunTargetKind _targetKind = _RunTargetKind.primary;
  String? _selectedWorktreeId;
  WorkspaceCapabilities? _capabilities;

  String? _workflowError;
  String? _submitError;

  List<RunAttachmentDraft> _attachments = const <RunAttachmentDraft>[];
  int _pastedCount = 0;
  bool _dragOver = false;
  List<String> _attachmentErrors = const <String>[];
  StreamSubscription<AttachmentDropEvent>? _dropSub;

  int _capabilitiesToken = 0;

  List<Worktree> get _existingWorktrees =>
      _worktrees.where((w) => !w.isPrimary).toList();

  bool get _worktreeAvailable {
    final workspace = _selectedWorkspace;
    if (workspace == null || !workspace.isGit) return false;
    return _hasGitWorktreeSupport(_capabilities);
  }

  static bool _hasGitWorktreeSupport(WorkspaceCapabilities? caps) =>
      caps != null && caps.gitAvailable && caps.isGitRepo && caps.hasCommits;

  @override
  void initState() {
    super.initState();
    _selectedWorkflowId = widget.initialWorkflowId;
    _dropSub = ref
        .read(attachmentInputSourceProvider)
        .drops
        .listen(_onDropEvent);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    unawaited(_dropSub?.cancel());
    _branchController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onDropEvent(AttachmentDropEvent event) {
    if (!mounted || _isSubmitting) return;
    switch (event) {
      case AttachmentDragEntered():
        if (!_dragOver) setState(() => _dragOver = true);
      case AttachmentDragExited():
        if (_dragOver) setState(() => _dragOver = false);
      case AttachmentFilesDropped(:final files):
        setState(() => _dragOver = false);
        _addCandidates(files);
    }
  }

  Future<void> _paste() async {
    if (_isSubmitting) return;
    final bytes = await ref
        .read(attachmentInputSourceProvider)
        .readClipboardImage();
    if (!mounted) return;
    if (bytes == null) {
      final focusContext = _inputFocusNode.context;
      if (focusContext != null && focusContext.mounted) {
        Actions.maybeInvoke<PasteTextIntent>(
          focusContext,
          const PasteTextIntent(SelectionChangedCause.keyboard),
        );
      }
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final mime = sniffImageMimeType(bytes);
    final ext = mime == null ? 'png' : extensionForMime(mime);
    final fileName = l10n.startRunPastedImageName(_pastedCount + 1, ext);
    final accepted = _addCandidates(<RunAttachmentCandidate>[
      RunAttachmentCandidate(
        fileName: fileName,
        sizeBytes: bytes.length,
        bytes: bytes,
      ),
    ]);
    if (accepted > 0) {
      _pastedCount += 1;
    }
  }

  int _addCandidates(List<RunAttachmentCandidate> candidates) {
    final l10n = AppLocalizations.of(context)!;
    final result = addRunAttachments(_attachments, candidates);
    final errors = <String>[];
    var addedLimitError = false;
    for (final (name, reason) in result.rejected) {
      switch (reason) {
        case RunAttachmentRejection.type:
          errors.add(l10n.startRunAttachmentTypeError(name));
        case RunAttachmentRejection.limits:
          if (!addedLimitError) {
            addedLimitError = true;
            errors.add(
              l10n.startRunAttachmentLimitError(
                RunAttachmentLimits.maxCount,
                RunAttachmentLimits.maxBytesEach ~/ 1048576,
                RunAttachmentLimits.maxTotalBytes ~/ 1048576,
              ),
            );
          }
      }
    }

    setState(() {
      _attachments = <RunAttachmentDraft>[..._attachments, ...result.accepted];
      _attachmentErrors = errors;
      _submitError = null;
    });

    final view = View.of(context);
    for (final draft in result.accepted) {
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          l10n.startRunAttachmentAdded(draft.fileName),
          TextDirection.ltr,
        ),
      );
    }
    return result.accepted.length;
  }

  Future<void> _loadInitial() async {
    WorkspaceRegistryState? registry;
    try {
      registry = await ref.read(workspaceRegistryControllerProvider.future);
    } on Object {
      registry = null;
    }
    final workspaces = registry?.workspaces ?? const <Workspace>[];
    final workspaceId = _preselectedWorkspaceId(
      workspaces,
      registry?.currentWorkspaceId,
    );
    final workflows = await _fetchWorkflows(workspaceId);
    if (!mounted) return;

    setState(() {
      _workflows = workflows;
      _workspaces = workspaces;
      _selectedWorkflowId = _keptWorkflowId(workflows);
      _selectedWorkspaceId = workspaceId;
      _isLoadingInitial = false;
    });

    await _loadWorkspaceContext(_selectedWorkspace);
  }

  /// Global workflows plus those of [workspaceId].
  Future<List<WorkflowSummary>> _fetchWorkflows(String? workspaceId) async =>
      (await ref.read(listWorkflowsProvider).call(workspaceId: workspaceId))
          .valueOrNull ??
      const <WorkflowSummary>[];

  /// The selected workflow when [workflows] still has it, else the first.
  String? _keptWorkflowId(List<WorkflowSummary> workflows) {
    final selected = _selectedWorkflowId;
    if (selected != null && workflows.any((w) => w.id == selected)) {
      return selected;
    }
    return workflows.isNotEmpty ? workflows.first.id : null;
  }

  Future<void> _reloadWorkflows(String? workspaceId) async {
    final workflows = await _fetchWorkflows(workspaceId);
    if (!mounted || workspaceId != _selectedWorkspaceId) return;
    setState(() {
      _workflows = workflows;
      _selectedWorkflowId = _keptWorkflowId(workflows);
    });
  }

  /// The workspace the dialog opens on: the one it was launched for, else the
  /// current workspace, else the first registered one.
  String? _preselectedWorkspaceId(
    List<Workspace> workspaces,
    String? currentWorkspaceId,
  ) {
    for (final candidate in <String?>[
      widget.initialWorkspaceId,
      currentWorkspaceId,
    ]) {
      if (candidate != null && workspaces.any((w) => w.id == candidate)) {
        return candidate;
      }
    }
    return workspaces.isEmpty ? null : workspaces.first.id;
  }

  Workspace? get _selectedWorkspace {
    final id = _selectedWorkspaceId;
    if (id == null) return null;
    for (final workspace in _workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  Future<void> _loadWorkspaceContext(Workspace? workspace) async {
    final token = ++_capabilitiesToken;
    if (workspace == null || !workspace.isGit) {
      setState(() {
        _capabilities = null;
        _worktrees = const <Worktree>[];
        _isCheckingCapabilities = false;
        _targetKind = _RunTargetKind.primary;
        _selectedWorktreeId = null;
      });
      return;
    }

    setState(() => _isCheckingCapabilities = true);
    final capsFuture = ref
        .read(getWorkspaceCapabilitiesProvider)
        .call(path: workspace.rootPath);
    final worktreesFuture = ref.read(listWorktreesProvider).call(workspace.id);
    final settingsFuture = _loadDefaultIsolationMode(workspace.id);

    final capsResult = await capsFuture;
    final worktreesResult = await worktreesFuture;
    final defaultMode = await settingsFuture;
    if (!mounted || token != _capabilitiesToken) return;

    final caps = capsResult.valueOrNull;
    final worktrees = worktreesResult.valueOrNull ?? const <Worktree>[];
    final existing = worktrees.where((w) => !w.isPrimary).toList();
    final canWorktree = _hasGitWorktreeSupport(caps);

    var nextKind = _targetKind;
    var nextWorktreeId = _selectedWorktreeId;

    final defaultKind = defaultMode == WorkspaceIsolationMode.worktree
        ? _RunTargetKind.newWorktree
        : _RunTargetKind.primary;

    if (_appliedInitialWorktree) {
      // The user switched workspace: its own effective default applies.
      nextKind = defaultKind;
    } else {
      _appliedInitialWorktree = true;
      final initialWorktreeId = widget.initialWorktreeId;
      if (initialWorktreeId == null) {
        // The tree context wins; without one the effective default applies.
        nextKind = defaultKind;
      } else if (initialWorktreeId == primaryWorktreeId) {
        nextKind = _RunTargetKind.primary;
      } else if (canWorktree &&
          existing.any((w) => w.id == initialWorktreeId)) {
        nextKind = _RunTargetKind.existingWorktree;
        nextWorktreeId = initialWorktreeId;
      }
    }

    if (nextWorktreeId == null ||
        !existing.any((w) => w.id == nextWorktreeId)) {
      nextWorktreeId = existing.isNotEmpty ? existing.first.id : null;
    }

    if (!canWorktree ||
        (nextKind == _RunTargetKind.existingWorktree && existing.isEmpty)) {
      nextKind = _RunTargetKind.primary;
    }

    setState(() {
      _capabilities = caps;
      _worktrees = worktrees;
      _isCheckingCapabilities = false;
      _targetKind = nextKind;
      _selectedWorktreeId = nextWorktreeId;
    });
  }

  /// The effective default isolation mode of [workspaceId], or `null` when
  /// the settings cannot be loaded (the dialog then defaults to the primary
  /// checkout).
  Future<WorkspaceIsolationMode?> _loadDefaultIsolationMode(
    String workspaceId,
  ) async {
    try {
      final result = await ref.read(getWorkspaceSettingsProvider)(workspaceId);
      return result.valueOrNull?.effective.defaultIsolationMode;
    } on Object {
      return null;
    }
  }

  RunTarget _buildTarget() {
    if (!_worktreeAvailable) {
      return const RunTarget.primary();
    }
    return switch (_targetKind) {
      _RunTargetKind.primary => const RunTarget.primary(),
      _RunTargetKind.existingWorktree => RunTarget.worktree(
        worktreeId: _selectedWorktreeId!,
      ),
      _RunTargetKind.newWorktree => RunTarget.newWorktree(
        branch: _branchController.text.trim().isEmpty
            ? null
            : _branchController.text.trim(),
      ),
    };
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final workflowId = _selectedWorkflowId;
    final workspaceId = _selectedWorkspaceId;

    String? workflowError;
    if (workflowId == null || workflowId.isEmpty) {
      workflowError = l10n.startRunValidationWorkflowRequired;
    }
    if (workflowError != null || workspaceId == null) {
      setState(() => _workflowError = workflowError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _workflowError = null;
      _submitError = null;
    });

    final rawInput = _inputController.text.trim();
    final input = rawInput.isEmpty ? null : rawInput;

    final result = await ref
        .read(startRunProvider)
        .call(
          StartRunRequest(
            workflowId: workflowId!,
            workspaceId: workspaceId,
            target: _buildTarget(),
            input: input,
            attachments: _attachments.isEmpty
                ? null
                : <RunAttachmentPayload>[
                    for (final attachment in _attachments)
                      attachment.toPayload(),
                  ],
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

  String _targetHelperText(AppLocalizations l10n) {
    return switch (_targetKind) {
      _RunTargetKind.primary => l10n.startRunTargetPrimaryDescription,
      _RunTargetKind.existingWorktree =>
        l10n.startRunTargetExistingWorktreeDescription,
      _RunTargetKind.newWorktree => l10n.startRunTargetNewWorktreeDescription,
    };
  }

  String _nonGitExplanation(AppLocalizations l10n) {
    final caps = _capabilities;
    if (caps != null && !caps.gitAvailable) {
      return l10n.startRunWorktreeUnavailableNoGit;
    }
    return l10n.startRunNonGitExplanation;
  }

  String _worktreeLabel(Worktree worktree) {
    final branch = worktree.branch;
    if (branch == null || branch.isEmpty || branch == worktree.name) {
      return worktree.name;
    }
    return '${worktree.name} ($branch)';
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

    final workspaceOptions = <HiveSelectOption<String>>[
      for (final workspace in _workspaces)
        HiveSelectOption<String>(value: workspace.id, label: workspace.name),
    ];

    final existingWorktrees = _existingWorktrees;
    final worktreeOptions = <HiveSelectOption<String>>[
      for (final worktree in existingWorktrees)
        HiveSelectOption<String>(
          value: worktree.id,
          label: _worktreeLabel(worktree),
        ),
    ];

    return HiveDialog(
      title: l10n.startRunDialogTitle,
      icon: HiveIcons.runs,
      dropActive: _dragOver,
      dropCaption: l10n.startRunAttachmentDropCaption,
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
                if (_workspaces.isEmpty)
                  HiveBanner(
                    key: const Key('start_run_no_workspaces_banner'),
                    tone: HiveFeedbackTone.warning,
                    title: l10n.startRunNoWorkspacesMessage,
                  )
                else
                  HiveSelect<String>(
                    key: const Key('start_run_workspace_select'),
                    label: l10n.startRunWorkspaceLabel,
                    options: workspaceOptions,
                    value: _selectedWorkspaceId,
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedWorkspaceId = value;
                              _submitError = null;
                            });
                            unawaited(
                              _loadWorkspaceContext(_selectedWorkspace),
                            );
                            unawaited(_reloadWorkflows(value));
                          },
                  ),
                if (_selectedWorkspace != null) ...<Widget>[
                  SizedBox(height: spacing.space3),
                  if (_isCheckingCapabilities)
                    Text(
                      l10n.startRunCheckingCapabilities,
                      style: typography.bodySmall.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    )
                  else if (!_worktreeAvailable)
                    HiveBanner(
                      key: const Key('start_run_non_git_banner'),
                      tone: HiveFeedbackTone.info,
                      title: _nonGitExplanation(l10n),
                    )
                  else ...<Widget>[
                    Text(
                      l10n.startRunTargetLabel,
                      style: typography.label.copyWith(color: colors.onSurface),
                    ),
                    SizedBox(height: spacing.space1),
                    Wrap(
                      spacing: spacing.space2,
                      runSpacing: spacing.space1,
                      children: <Widget>[
                        HiveFilterChip(
                          key: const Key('start_run_target_primary'),
                          label: l10n.startRunTargetPrimary,
                          selected: _targetKind == _RunTargetKind.primary,
                          onSelected: _isSubmitting
                              ? null
                              : (_) => setState(() {
                                  _targetKind = _RunTargetKind.primary;
                                  _submitError = null;
                                }),
                        ),
                        HiveFilterChip(
                          key: const Key('start_run_target_existing_worktree'),
                          label: l10n.startRunTargetExistingWorktree,
                          selected:
                              _targetKind == _RunTargetKind.existingWorktree,
                          onSelected:
                              (!_isSubmitting && existingWorktrees.isNotEmpty)
                              ? (_) => setState(() {
                                  _targetKind = _RunTargetKind.existingWorktree;
                                  _submitError = null;
                                })
                              : null,
                        ),
                        HiveFilterChip(
                          key: const Key('start_run_target_new_worktree'),
                          label: l10n.startRunTargetNewWorktree,
                          selected: _targetKind == _RunTargetKind.newWorktree,
                          onSelected: _isSubmitting
                              ? null
                              : (_) => setState(() {
                                  _targetKind = _RunTargetKind.newWorktree;
                                  _submitError = null;
                                }),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.space1),
                    Text(
                      _targetHelperText(l10n),
                      style: typography.bodySmall.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                    if (_targetKind ==
                        _RunTargetKind.existingWorktree) ...<Widget>[
                      SizedBox(height: spacing.space3),
                      HiveSelect<String>(
                        key: const Key('start_run_worktree_select'),
                        label: l10n.startRunExistingWorktreeLabel,
                        hint: l10n.startRunExistingWorktreeHint,
                        options: worktreeOptions,
                        value: _selectedWorktreeId,
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() {
                                _selectedWorktreeId = value;
                                _submitError = null;
                              }),
                      ),
                    ],
                    if (_targetKind == _RunTargetKind.newWorktree) ...<Widget>[
                      SizedBox(height: spacing.space3),
                      HiveTextField(
                        key: const Key('start_run_branch_field'),
                        label: l10n.startRunNewWorktreeBranchLabel,
                        hint: l10n.startRunNewWorktreeBranchHint,
                        controller: _branchController,
                        enabled: !_isSubmitting,
                        onChanged: (_) {
                          if (_submitError != null) {
                            setState(() => _submitError = null);
                          }
                        },
                      ),
                    ],
                  ],
                ],
                SizedBox(height: spacing.space3),
                Shortcuts(
                  shortcuts: const <ShortcutActivator, Intent>{
                    SingleActivator(LogicalKeyboardKey.keyV, control: true):
                        _PasteIntent(),
                    SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                        _PasteIntent(),
                  },
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      _PasteIntent: CallbackAction<_PasteIntent>(
                        onInvoke: (_) {
                          unawaited(_paste());
                          return null;
                        },
                      ),
                    },
                    child: HiveTextArea(
                      key: const Key('start_run_input_field'),
                      label: l10n.startRunInputLabel,
                      hintText: l10n.startRunInputHint,
                      helperText: l10n.startRunInputHelper,
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      minLines: 3,
                      maxLines: 5,
                      enabled: !_isSubmitting,
                    ),
                  ),
                ),
                if (_attachments.isNotEmpty) ...<Widget>[
                  SizedBox(height: spacing.space2),
                  Wrap(
                    spacing: spacing.space2,
                    runSpacing: spacing.space1,
                    children: <Widget>[
                      for (var i = 0; i < _attachments.length; i++)
                        HiveRemovableChip(
                          key: Key('start_run_attachment_chip_$i'),
                          label: l10n.startRunAttachmentChipLabel(
                            _attachments[i].fileName,
                            RunL10n.formatAttachmentSize(
                              l10n,
                              _attachments[i].sizeBytes,
                            ),
                          ),
                          removeSemanticLabel: l10n.startRunAttachmentRemove(
                            _attachments[i].fileName,
                          ),
                          onRemoved: _isSubmitting
                              ? null
                              : () => setState(() {
                                  _attachments = <RunAttachmentDraft>[
                                    ..._attachments.take(i),
                                    ..._attachments.skip(i + 1),
                                  ];
                                  _attachmentErrors = const <String>[];
                                }),
                        ),
                    ],
                  ),
                ],
                if (_attachmentErrors.isNotEmpty) ...<Widget>[
                  SizedBox(height: spacing.space2),
                  HiveBanner(
                    key: const Key('start_run_attachment_error_banner'),
                    tone: HiveFeedbackTone.danger,
                    title: _attachmentErrors.join('\n'),
                    liveRegion: true,
                  ),
                ],
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
          onPressed:
              (_isLoadingInitial ||
                  _isSubmitting ||
                  _workflows.isEmpty ||
                  _selectedWorkspaceId == null)
              ? null
              : () => unawaited(_submit()),
        ),
      ],
    );
  }
}
