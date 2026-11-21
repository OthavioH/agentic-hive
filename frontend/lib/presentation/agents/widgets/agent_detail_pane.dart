import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_slug.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_state.dart';
import 'package:agentic_hive_frontend/presentation/agents/widgets/chip_list_editor.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Detail pane of the Agents library: empty state, parse-error inspector, or
/// structured frontmatter + Markdown prompt editor.
class AgentDetailPane extends StatefulWidget {
  /// Creates an [AgentDetailPane].
  const new({
    required this.state,
    required this.onNameChanged,
    required this.onSlugChanged,
    required this.onDescriptionChanged,
    required this.onPromptChanged,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onAddRequiredSkill,
    required this.onRemoveRequiredSkill,
    required this.onAddRequiredTool,
    required this.onRemoveRequiredTool,
    required this.onAddAllowedTool,
    required this.onRemoveAllowedTool,
    required this.onAddDeniedTool,
    required this.onRemoveDeniedTool,
    required this.onInsertTemplate,
    required this.onPreviewModeChanged,
    required this.onSave,
    required this.onDelete,
    required this.onReload,
    required this.onDismissExternalNotice,
    required this.onDismissSaveError,
    required this.onBackToList,
    super.key,
  });

  /// Current controller state.
  final AgentsState state;

  /// Called when the agent name changes.
  final ValueChanged<String> onNameChanged;

  /// Called when the agent slug changes (creation only).
  final ValueChanged<String> onSlugChanged;

  /// Called when the description changes.
  final ValueChanged<String> onDescriptionChanged;

  /// Called when the Markdown prompt changes.
  final ValueChanged<String> onPromptChanged;

  /// Adds a tag.
  final ValueChanged<String> onAddTag;

  /// Removes a tag.
  final ValueChanged<String> onRemoveTag;

  /// Adds a required skill.
  final ValueChanged<String> onAddRequiredSkill;

  /// Removes a required skill.
  final ValueChanged<String> onRemoveRequiredSkill;

  /// Adds a required tool.
  final ValueChanged<String> onAddRequiredTool;

  /// Removes a required tool.
  final ValueChanged<String> onRemoveRequiredTool;

  /// Adds an allowed tool.
  final ValueChanged<String> onAddAllowedTool;

  /// Removes an allowed tool.
  final ValueChanged<String> onRemoveAllowedTool;

  /// Adds a denied tool.
  final ValueChanged<String> onAddDeniedTool;

  /// Removes a denied tool.
  final ValueChanged<String> onRemoveDeniedTool;

  /// Inserts the starter Markdown template.
  final VoidCallback onInsertTemplate;

  /// Toggles Raw (`false`) vs Preview (`true`) mode.
  final ValueChanged<bool> onPreviewModeChanged;

  /// Saves the current draft.
  final VoidCallback onSave;

  /// Prompts to delete the selected agent.
  final VoidCallback onDelete;

  /// Reloads the selected agent from disk.
  final VoidCallback onReload;

  /// Dismisses the external-change banner.
  final VoidCallback onDismissExternalNotice;

  /// Dismisses the save-error banner.
  final VoidCallback onDismissSaveError;

  /// Clears selection on narrow layouts.
  final VoidCallback onBackToList;

  @override
  State<AgentDetailPane> createState() => _AgentDetailPaneState();
}

class _AgentDetailPaneState extends State<AgentDetailPane> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllers(widget.state.draft);
  }

  @override
  void didUpdateWidget(AgentDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers(widget.state.draft);
  }

  void _syncControllers(AgentDraft? draft) {
    if (draft == null) return;
    if (_nameController.text != draft.name) {
      _nameController.text = draft.name;
    }
    if (_slugController.text != draft.id) {
      _slugController.text = draft.id;
    }
    if (_descriptionController.text != draft.description) {
      _descriptionController.text = draft.description;
    }
    if (_promptController.text != draft.prompt) {
      _promptController.text = draft.prompt;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!widget.state.hasDetailOpen) {
      return HiveEmptyState(
        icon: HiveIcons.agents,
        title: l10n.agentsSelectPromptTitle,
        message: l10n.agentsSelectPromptDescription,
      );
    }

    if (!widget.state.isCreating && widget.state.detail.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!widget.state.isCreating && widget.state.detail.hasError) {
      final error = widget.state.detail.error;
      final message = error is Failure ? error.message : error.toString();
      return Padding(
        padding: EdgeInsets.all(context.hiveSpacing.space3),
        child: Align(
          alignment: Alignment.topCenter,
          child: HiveBanner(
            tone: HiveFeedbackTone.danger,
            title: l10n.agentsDetailErrorTitle,
            message: message,
            actions: <Widget>[
              HiveButton(
                label: l10n.agentsRetryAction,
                variant: HiveButtonVariant.secondary,
                size: HiveButtonSize.small,
                onPressed: widget.onReload,
              ),
            ],
          ),
        ),
      );
    }

    final draft = widget.state.draft;
    if (draft == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (draft.parseError != null) {
      return _buildParseErrorView(context, l10n, draft);
    }

    return _buildEditorView(context, l10n, draft);
  }

  Widget _buildParseErrorView(
    BuildContext context,
    AppLocalizations l10n,
    AgentDraft draft,
  ) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final raw = draft.rawContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildActionBar(context, l10n, draft, allowSave: false),
        Divider(
          height: context.hiveElevation.hairline,
          thickness: context.hiveElevation.hairline,
          color: colors.borderSubtle,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.space3),
            child: HiveBanner(
              tone: HiveFeedbackTone.danger,
              title: l10n.agentsParseErrorTitle,
              message: draft.parseError,
              detail: raw == null
                  ? null
                  : Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(spacing.space2),
                      decoration: BoxDecoration(
                        color: colors.surface1,
                        borderRadius: context.hiveRadii.card,
                        border: Border.all(
                          color: colors.borderSubtle,
                          width: context.hiveElevation.hairline,
                        ),
                      ),
                      child: SelectableText(
                        raw,
                        style: typography.mono.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorView(
    BuildContext context,
    AppLocalizations l10n,
    AgentDraft draft,
  ) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final slugInvalid =
        widget.state.isCreating &&
        draft.id.isNotEmpty &&
        !AgentSlug.isValid(draft.id);
    final canSave =
        !widget.state.isSaving &&
        draft.name.trim().isNotEmpty &&
        (!widget.state.isCreating || AgentSlug.isValid(draft.id)) &&
        (widget.state.isCreating ||
            widget.state.isDirty ||
            widget.state.externalNotice ==
                ExternalChangeNotice.deletedExternally);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildActionBar(context, l10n, draft, allowSave: canSave),
        Divider(
          height: context.hiveElevation.hairline,
          thickness: context.hiveElevation.hairline,
          color: colors.borderSubtle,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (widget.state.externalNotice ==
                    ExternalChangeNotice.modifiedExternally) ...<Widget>[
                  HiveBanner(
                    tone: HiveFeedbackTone.warning,
                    title: l10n.agentsExternalModifiedTitle,
                    message: l10n.agentsExternalModifiedMessage,
                    liveRegion: true,
                    actions: <Widget>[
                      HiveButton(
                        label: l10n.agentsReloadAction,
                        variant: HiveButtonVariant.secondary,
                        size: HiveButtonSize.small,
                        onPressed: widget.onReload,
                      ),
                    ],
                    onDismiss: widget.onDismissExternalNotice,
                    dismissSemanticLabel: l10n.agentsDismissTooltip,
                  ),
                  SizedBox(height: spacing.space2),
                ],
                if (widget.state.externalNotice ==
                    ExternalChangeNotice.deletedExternally) ...<Widget>[
                  HiveBanner(
                    tone: HiveFeedbackTone.danger,
                    title: l10n.agentsExternalDeletedTitle,
                    message: l10n.agentsExternalDeletedMessage,
                    liveRegion: true,
                    onDismiss: widget.onDismissExternalNotice,
                    dismissSemanticLabel: l10n.agentsDismissTooltip,
                  ),
                  SizedBox(height: spacing.space2),
                ],
                if (widget.state.saveError != null) ...<Widget>[
                  HiveBanner(
                    tone: HiveFeedbackTone.danger,
                    title: widget.state.saveError!,
                    liveRegion: true,
                    onDismiss: widget.onDismissSaveError,
                    dismissSemanticLabel: l10n.agentsDismissTooltip,
                  ),
                  SizedBox(height: spacing.space2),
                ],
                HiveTextField(
                  label: l10n.agentsFieldName,
                  hintText: l10n.agentsFieldNameHint,
                  controller: _nameController,
                  onChanged: widget.onNameChanged,
                ),
                SizedBox(height: spacing.space2),
                HiveTextField(
                  label: l10n.agentsFieldSlug,
                  hintText: l10n.agentsFieldSlugHint,
                  helperText: l10n.agentsFieldSlugHelper,
                  errorText: slugInvalid ? l10n.agentsFieldSlugInvalid : null,
                  controller: _slugController,
                  enabled: widget.state.isCreating,
                  onChanged: widget.onSlugChanged,
                ),
                SizedBox(height: spacing.space2),
                HiveTextField(
                  label: l10n.agentsFieldDescription,
                  hintText: l10n.agentsFieldDescriptionHint,
                  controller: _descriptionController,
                  onChanged: widget.onDescriptionChanged,
                ),
                SizedBox(height: spacing.space2),
                ChipListEditor(
                  label: l10n.agentsFieldTags,
                  hintText: l10n.agentsFieldTagsHint,
                  items: draft.tags,
                  onAdd: widget.onAddTag,
                  onRemove: widget.onRemoveTag,
                ),
                SizedBox(height: spacing.space3),
                HiveCollapsibleSection(
                  title: l10n.agentsCapabilitiesTitle,
                  subtitle: l10n.agentsCapabilitiesSubtitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ChipListEditor(
                        label: l10n.agentsFieldRequiredSkills,
                        hintText: l10n.agentsFieldRequiredSkillsHint,
                        items: draft.requiredSkills,
                        onAdd: widget.onAddRequiredSkill,
                        onRemove: widget.onRemoveRequiredSkill,
                      ),
                      SizedBox(height: spacing.space2),
                      ChipListEditor(
                        label: l10n.agentsFieldRequiredTools,
                        hintText: l10n.agentsFieldRequiredToolsHint,
                        items: draft.requiredTools,
                        onAdd: widget.onAddRequiredTool,
                        onRemove: widget.onRemoveRequiredTool,
                      ),
                      SizedBox(height: spacing.space2),
                      ChipListEditor(
                        label: l10n.agentsFieldAllowedTools,
                        hintText: l10n.agentsFieldAllowedToolsHint,
                        items: draft.allowedTools,
                        onAdd: widget.onAddAllowedTool,
                        onRemove: widget.onRemoveAllowedTool,
                      ),
                      SizedBox(height: spacing.space2),
                      ChipListEditor(
                        label: l10n.agentsFieldDeniedTools,
                        hintText: l10n.agentsFieldDeniedToolsHint,
                        items: draft.deniedTools,
                        onAdd: widget.onAddDeniedTool,
                        onRemove: widget.onRemoveDeniedTool,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing.space3),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.agentsFieldPrompt,
                        style: typography.labelLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    HiveSegmentedControl<bool>(
                      semanticLabel: l10n.agentsPromptModeLabel,
                      selected: widget.state.isPreviewMode,
                      onChanged: widget.onPreviewModeChanged,
                      segments: <HiveSegment<bool>>[
                        HiveSegment<bool>(
                          value: false,
                          label: l10n.agentsPromptModeRaw,
                        ),
                        HiveSegment<bool>(
                          value: true,
                          label: l10n.agentsPromptModePreview,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: spacing.space1),
                if (!widget.state.isPreviewMode)
                  HiveTextArea(
                    semanticLabel: l10n.agentsFieldPrompt,
                    hintText: l10n.agentsFieldPromptHint,
                    controller: _promptController,
                    mono: true,
                    minLines: 12,
                    onChanged: widget.onPromptChanged,
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(spacing.space2),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: context.hiveRadii.card,
                      border: Border.all(
                        color: colors.borderSubtle,
                        width: context.hiveElevation.hairline,
                      ),
                    ),
                    child: draft.prompt.trim().isEmpty
                        ? Text(
                            l10n.agentsPromptPreviewEmpty,
                            style: typography.body.copyWith(
                              color: colors.onSurfaceMuted,
                            ),
                          )
                        : HiveMarkdownView(data: draft.prompt),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    AppLocalizations l10n,
    AgentDraft draft, {
    required bool allowSave,
  }) {
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final colors = context.hiveColors;
    final title = widget.state.isCreating
        ? l10n.agentsNewAction
        : (draft.name.trim().isEmpty ? draft.id : draft.name);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space3,
        vertical: spacing.space2,
      ),
      child: Row(
        children: <Widget>[
          HiveIconButton(
            icon: HiveIcons.collapseRail,
            semanticLabel: l10n.agentsBackToListAction,
            size: HiveButtonSize.small,
            onPressed: widget.onBackToList,
          ),
          SizedBox(width: spacing.space1),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.titleSmall.copyWith(color: colors.onSurface),
            ),
          ),
          if (widget.state.isCreating) ...<Widget>[
            HiveButton(
              label: l10n.agentsInsertTemplateAction,
              variant: HiveButtonVariant.secondary,
              size: HiveButtonSize.small,
              onPressed: widget.onInsertTemplate,
            ),
            SizedBox(width: spacing.space1),
          ],
          if (!widget.state.isCreating) ...<Widget>[
            HiveButton(
              label: l10n.agentsDeleteAction,
              icon: HiveIcons.delete,
              variant: HiveButtonVariant.ghost,
              size: HiveButtonSize.small,
              loading: widget.state.isDeleting,
              onPressed: widget.state.isDeleting ? null : widget.onDelete,
            ),
            SizedBox(width: spacing.space1),
          ],
          if (draft.parseError == null)
            HiveButton(
              label: l10n.agentsSaveAction,
              icon: HiveIcons.check,
              size: HiveButtonSize.small,
              loading: widget.state.isSaving,
              onPressed: allowSave ? widget.onSave : null,
            ),
        ],
      ),
    );
  }
}
