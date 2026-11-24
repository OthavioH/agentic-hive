import 'package:agentic_hive_frontend/domain/pauses/use_cases/validate_proposal_draft.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_state.dart';
import 'package:agentic_hive_frontend/presentation/pauses/utils/pause_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Detail pane for reviewing and responding to a selected [Pause].
class PauseDetailPane extends StatefulWidget {
  /// Creates a [PauseDetailPane].
  const new({
    required this.pause,
    required this.state,
    required this.onOpenRun,
    required this.onApprove,
    required this.onReject,
    required this.onSubmitAnswer,
    required this.onFeedbackDraftChanged,
    required this.onAnswerDraftChanged,
    required this.onStartProposalEdit,
    required this.onProposalDraftChanged,
    required this.onDiscardProposalEdit,
    required this.onDismissNotice,
    this.proposalCheck,
    super.key,
  });

  /// Selected pause to display.
  final Pause pause;

  /// Current inbox controller state.
  final PausesState state;

  /// Validation result for the active proposal draft, if editing.
  final ProposalDraftCheck? proposalCheck;

  /// Called when the user clicks the run link in the detail header.
  final ValueChanged<String> onOpenRun;

  /// Called when approving a `humanApproval` pause with optional feedback and
  /// edited proposal.
  final void Function(String? feedback, Object? proposal) onApprove;

  /// Called when rejecting a `humanApproval` pause with optional feedback.
  final ValueChanged<String?> onReject;

  /// Called when submitting an `askHuman` answer.
  final ValueChanged<String> onSubmitAnswer;

  /// Called when the user edits the optional feedback draft for the selected
  /// pause.
  final ValueChanged<String> onFeedbackDraftChanged;

  /// Called when the user edits the answer draft for the selected pause.
  final ValueChanged<String> onAnswerDraftChanged;

  /// Called when entering proposal edit mode with the seeded JSON text.
  final ValueChanged<String> onStartProposalEdit;

  /// Called when the user edits the proposal JSON draft.
  final ValueChanged<String> onProposalDraftChanged;

  /// Called when the user discards proposal edits.
  final VoidCallback onDiscardProposalEdit;

  /// Called to dismiss a conflict or error banner.
  final VoidCallback onDismissNotice;

  @override
  State<PauseDetailPane> createState() => _PauseDetailPaneState();
}

class _PauseDetailPaneState extends State<PauseDetailPane> {
  late final TextEditingController _feedbackController;
  late final TextEditingController _answerController;
  late final TextEditingController _proposalController;
  String? _answerValidationError;

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController(
      text: widget.state.feedbackDraftFor(widget.pause.id),
    );
    _answerController = TextEditingController(
      text: widget.state.answerDraftFor(widget.pause.id),
    );
    _proposalController = TextEditingController(
      text: widget.state.proposalDraftFor(widget.pause.id) ?? '',
    );
  }

  @override
  void didUpdateWidget(PauseDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pause.id != widget.pause.id) {
      final nextFeedback = widget.state.feedbackDraftFor(widget.pause.id);
      final nextAnswer = widget.state.answerDraftFor(widget.pause.id);
      final nextProposal = widget.state.proposalDraftFor(widget.pause.id) ?? '';
      _feedbackController
        ..text = nextFeedback
        ..selection = TextSelection.collapsed(offset: nextFeedback.length);
      _answerController
        ..text = nextAnswer
        ..selection = TextSelection.collapsed(offset: nextAnswer.length);
      _proposalController
        ..text = nextProposal
        ..selection = TextSelection.collapsed(offset: nextProposal.length);
      _answerValidationError = null;
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _answerController.dispose();
    _proposalController.dispose();
    super.dispose();
  }

  void _selectOptionChip(String option) {
    setState(() {
      _answerController
        ..text = option
        ..selection = TextSelection.collapsed(offset: option.length);
      _answerValidationError = null;
    });
    widget.onAnswerDraftChanged(option);
  }

  void _handleSubmitAnswer(AppLocalizations l10n) {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _answerValidationError = l10n.pausesAnswerRequiredError;
      });
      return;
    }
    setState(() {
      _answerValidationError = null;
    });
    widget.onSubmitAnswer(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final pause = widget.pause;
    final kindText = pause.kind.label(l10n);
    final waitingText = PauseL10n.formatWaitingTime(
      l10n,
      pause.createdAt,
      now: widget.state.now,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.state.hasConflict) ...<Widget>[
            HiveBanner(
              key: const Key('pauses_conflict_banner'),
              tone: HiveFeedbackTone.warning,
              liveRegion: true,
              title: l10n.pausesConflictMessage,
              onDismiss: widget.onDismissNotice,
              dismissSemanticLabel: l10n.pausesDismissNoticeSemantic,
            ),
            SizedBox(height: spacing.space2),
          ] else if (widget.state.submitFailure != null) ...<Widget>[
            HiveBanner(
              key: const Key('pauses_submit_error_banner'),
              tone: HiveFeedbackTone.danger,
              liveRegion: true,
              title: l10n.pausesSubmitErrorTitle,
              message: PauseL10n.localizeError(
                l10n,
                widget.state.submitFailure,
              ),
              onDismiss: widget.onDismissNotice,
              dismissSemanticLabel: l10n.pausesDismissNoticeSemantic,
            ),
            SizedBox(height: spacing.space2),
          ],
          HiveCard(
            surface: HiveCardSurface.surface2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    HiveStatusDot(
                      status: HiveNodeStatus.paused,
                      semanticLabel: l10n.pausesStatusPending,
                    ),
                    SizedBox(width: spacing.space1),
                    HiveBadge(label: kindText, tone: pause.kind.badgeTone),
                    SizedBox(width: spacing.space2),
                    Text(
                      waitingText,
                      style: typography.label.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                    const Spacer(),
                    HiveButton(
                      key: const Key('pauses_open_run_button'),
                      label: l10n.pausesOpenRunAction,
                      semanticLabel: l10n.pausesOpenRunSemantic(pause.runId),
                      variant: HiveButtonVariant.ghost,
                      size: HiveButtonSize.small,
                      icon: HiveIcons.runs,
                      onPressed: () => widget.onOpenRun(pause.runId),
                    ),
                  ],
                ),
                SizedBox(height: spacing.space2),
                Text(
                  pause.workflowName,
                  style: typography.titleSmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                SizedBox(height: spacing.spaceHalf),
                Text(
                  pause.nodeLabel,
                  style: typography.body.copyWith(color: colors.onSurfaceMuted),
                ),
                SizedBox(height: spacing.space3),
                if (pause.kind == PauseKind.humanApproval)
                  _buildApprovalSection(context, l10n, pause)
                else
                  _buildQuestionSection(context, l10n, pause),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalSection(
    BuildContext context,
    AppLocalizations l10n,
    Pause pause,
  ) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final isBusy = widget.state.isSubmitting;
    final submittingAction = widget.state.submittingAction;
    final title = pause.title;
    final instructions = pause.instructions;
    final hasProposal = pause.proposal != null;
    final isEditingProposal =
        hasProposal && widget.state.isEditingProposal(pause.id);

    Object? approvedProposal;
    var canApprove = !isBusy;
    if (isEditingProposal) {
      if (widget.proposalCheck case ProposalDraftValid(:final value)) {
        approvedProposal = value;
      } else {
        canApprove = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null && title.trim().isNotEmpty) ...<Widget>[
          Text(
            title,
            style: typography.labelLarge.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space1),
        ],
        if (instructions != null && instructions.trim().isNotEmpty) ...<Widget>[
          Text(
            instructions,
            style: typography.body.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space3),
        ],
        if (hasProposal) ...<Widget>[
          _buildProposalSection(
            context,
            l10n,
            pause,
            isBusy: isBusy,
            isEditing: isEditingProposal,
          ),
          SizedBox(height: spacing.space3),
        ],
        if (pause.allowFeedback) ...<Widget>[
          HiveTextField(
            key: const Key('pauses_feedback_field'),
            label: l10n.pausesFeedbackLabel,
            hintText: l10n.pausesFeedbackHint,
            controller: _feedbackController,
            multiline: true,
            enabled: !isBusy,
            onChanged: widget.onFeedbackDraftChanged,
          ),
          SizedBox(height: spacing.space3),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            HiveButton(
              key: const Key('pauses_reject_button'),
              label: submittingAction == PauseSubmittingAction.reject
                  ? l10n.pausesSubmittingLabel
                  : l10n.pausesRejectAction,
              variant: HiveButtonVariant.secondary,
              loading: submittingAction == PauseSubmittingAction.reject,
              onPressed: isBusy
                  ? null
                  : () => widget.onReject(_feedbackController.text),
            ),
            SizedBox(width: spacing.space2),
            HiveButton(
              key: const Key('pauses_approve_button'),
              label: submittingAction == PauseSubmittingAction.approve
                  ? l10n.pausesSubmittingLabel
                  : (isEditingProposal
                        ? l10n.pausesApproveEditedAction
                        : l10n.pausesApproveAction),
              loading: submittingAction == PauseSubmittingAction.approve,
              onPressed: canApprove
                  ? () => widget.onApprove(
                      _feedbackController.text,
                      approvedProposal,
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProposalSection(
    BuildContext context,
    AppLocalizations l10n,
    Pause pause, {
    required bool isBusy,
    required bool isEditing,
  }) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final source = pause.proposalSource;
    final headingText = source == null
        ? l10n.pausesProposalHeadingGeneric
        : l10n.pausesProposalHeading(source);

    final Widget actionButton;
    if (isEditing) {
      actionButton = HiveButton(
        key: const Key('pauses_proposal_discard_button'),
        label: l10n.pausesProposalDiscardAction,
        variant: HiveButtonVariant.ghost,
        size: HiveButtonSize.small,
        onPressed: isBusy ? null : widget.onDiscardProposalEdit,
      );
    } else {
      actionButton = HiveButton(
        key: const Key('pauses_proposal_edit_button'),
        label: l10n.pausesProposalEditAction,
        variant: HiveButtonVariant.secondary,
        size: HiveButtonSize.small,
        onPressed: isBusy
            ? null
            : () {
                final pretty = PauseL10n.prettyJson(pause.proposal);
                _proposalController
                  ..text = pretty
                  ..selection = TextSelection.collapsed(offset: pretty.length);
                widget.onStartProposalEdit(pretty);
              },
      );
    }

    final errorText = switch (widget.proposalCheck) {
      ProposalDraftInvalid(:final messages) => messages.join('\n'),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  headingText,
                  style: typography.labelLarge.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
            SizedBox(width: spacing.space2),
            actionButton,
          ],
        ),
        SizedBox(height: spacing.space1),
        if (isEditing)
          Semantics(
            liveRegion: true,
            child: HiveTextArea(
              key: const Key('pauses_proposal_field'),
              label: l10n.pausesProposalEditorLabel,
              mono: true,
              minLines: 6,
              maxLines: 16,
              controller: _proposalController,
              enabled: !isBusy,
              errorText: errorText,
              onChanged: widget.onProposalDraftChanged,
            ),
          )
        else
          HiveCodeBlock(
            key: const Key('pauses_proposal_view'),
            code: PauseL10n.prettyJson(pause.proposal),
            copyLabel: l10n.pausesProposalCopy,
          ),
      ],
    );
  }

  Widget _buildQuestionSection(
    BuildContext context,
    AppLocalizations l10n,
    Pause pause,
  ) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final isBusy = widget.state.isSubmitting;
    final question = pause.question;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (question != null && question.trim().isNotEmpty) ...<Widget>[
          Text(
            question,
            style: typography.body.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space3),
        ],
        if (pause.options.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: spacing.space1,
            runSpacing: spacing.space1,
            children: <Widget>[
              for (final option in pause.options)
                HiveFilterChip(
                  label: option,
                  selected: _answerController.text == option,
                  onSelected: isBusy ? null : (_) => _selectOptionChip(option),
                ),
            ],
          ),
          SizedBox(height: spacing.space2),
        ],
        HiveTextField(
          key: const Key('pauses_answer_field'),
          label: l10n.pausesAnswerLabel,
          hintText: l10n.pausesAnswerHint,
          controller: _answerController,
          multiline: true,
          enabled: !isBusy,
          errorText: _answerValidationError,
          onChanged: (value) {
            widget.onAnswerDraftChanged(value);
            if (_answerValidationError != null) {
              setState(() => _answerValidationError = null);
            } else {
              setState(() {});
            }
          },
        ),
        SizedBox(height: spacing.space3),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: HiveButton(
            key: const Key('pauses_submit_answer_button'),
            label: widget.state.submittingAction == PauseSubmittingAction.answer
                ? l10n.pausesSubmittingLabel
                : l10n.pausesSubmitAnswerAction,
            loading:
                widget.state.submittingAction == PauseSubmittingAction.answer,
            onPressed: isBusy ? null : () => _handleSubmitAnswer(l10n),
          ),
        ),
      ],
    );
  }
}
