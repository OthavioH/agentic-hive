import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector configuration form for `human_approval`
/// ([HumanApprovalNodeConfig]).
class HumanApprovalConfigForm extends StatefulWidget {
  /// Creates a [HumanApprovalConfigForm].
  const new({
    required this.node,
    required this.onConfigChanged,
    this.upstreamNodes = const <WorkflowNode>[],
    super.key,
  });

  /// Node being edited.
  final WorkflowNode node;

  /// Emits the updated raw `JsonMap` configuration.
  final ValueChanged<JsonMap> onConfigChanged;

  /// Other nodes in the workflow that can supply a proposal.
  final List<WorkflowNode> upstreamNodes;

  @override
  State<HumanApprovalConfigForm> createState() =>
      _HumanApprovalConfigFormState();
}

class _HumanApprovalConfigFormState extends State<HumanApprovalConfigForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _proposalPathController = TextEditingController();
  final TextEditingController _proposalSchemaController =
      TextEditingController();

  bool _allowFeedback = true;
  String? _proposalNodeId;

  @override
  void initState() {
    super.initState();
    _syncFromNode();
  }

  @override
  void didUpdateWidget(HumanApprovalConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _proposalPathController.dispose();
    _proposalSchemaController.dispose();
    super.dispose();
  }

  void _syncFromNode() {
    final config = _parseConfig(widget.node.config);
    _titleController.text = config.title ?? '';
    _instructionsController.text = config.instructions;
    _allowFeedback = config.allowFeedback;
    _proposalNodeId = _blankToNull(config.proposalNodeId ?? '');
    _proposalPathController.text = config.proposalPath ?? '';
    _proposalSchemaController.text = config.proposalSchema ?? '';
  }

  HumanApprovalNodeConfig _parseConfig(JsonMap raw) {
    try {
      return HumanApprovalNodeConfig.fromJson(raw);
    } on FormatException {
      return const HumanApprovalNodeConfig(instructions: '');
    }
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  HumanApprovalNodeConfig _currentConfig() {
    final proposalNodeId = _proposalNodeId;
    return HumanApprovalNodeConfig(
      title: _blankToNull(_titleController.text),
      instructions: _instructionsController.text,
      allowFeedback: _allowFeedback,
      proposalNodeId: proposalNodeId,
      proposalPath: proposalNodeId == null
          ? null
          : _blankToNull(_proposalPathController.text),
      proposalSchema: proposalNodeId == null
          ? null
          : _blankToNull(_proposalSchemaController.text),
    );
  }

  void _emit() {
    widget.onConfigChanged(_currentConfig().toJson());
  }

  String? _issueFor(List<NodeConfigIssue> issues, String field) {
    final messages = issues
        .where((issue) => issue.field == field)
        .map((issue) => issue.message)
        .toList(growable: false);
    return messages.isEmpty ? null : messages.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final issues = _currentConfig().validate();
    final proposalNodeId = _proposalNodeId;
    final hasDanglingNode =
        proposalNodeId != null &&
        !widget.upstreamNodes.any((n) => n.id == proposalNodeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HiveTextField(
          key: const Key('config_human_title'),
          label: l10n.nodeConfigHumanTitleLabel,
          hint: l10n.nodeConfigHumanTitleHint,
          controller: _titleController,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_human_instructions'),
          label: l10n.nodeConfigHumanInstructionsLabel,
          hint: l10n.nodeConfigHumanInstructionsHint,
          controller: _instructionsController,
          multiline: true,
          maxLines: 4,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveSwitch(
          key: const Key('config_human_allow_feedback'),
          label: l10n.nodeConfigHumanAllowFeedbackLabel,
          value: _allowFeedback,
          onChanged: (value) {
            setState(() => _allowFeedback = value);
            _emit();
          },
        ),
        SizedBox(height: spacing.space3),
        Semantics(
          header: true,
          child: Text(
            l10n.nodeConfigHumanProposalHeading,
            style: typography.labelLarge.copyWith(color: colors.onSurface),
          ),
        ),
        SizedBox(height: spacing.space2),
        HiveSelect<String?>(
          key: const Key('config_human_proposal_node'),
          label: l10n.nodeConfigHumanProposalNodeLabel,
          hint: l10n.nodeConfigHumanProposalNodeNone,
          value: proposalNodeId,
          errorText: _issueFor(issues, 'proposalNodeId'),
          options: <HiveSelectOption<String?>>[
            HiveSelectOption<String?>(
              value: null,
              label: l10n.nodeConfigHumanProposalNodeNone,
            ),
            if (hasDanglingNode)
              HiveSelectOption<String?>(
                value: proposalNodeId,
                label: proposalNodeId,
              ),
            for (final node in widget.upstreamNodes)
              HiveSelectOption<String?>(
                value: node.id,
                label: node.label.isEmpty ? node.id : node.label,
              ),
          ],
          onChanged: (value) {
            setState(() {
              _proposalNodeId = value;
              if (value == null) {
                _proposalPathController.clear();
                _proposalSchemaController.clear();
              }
            });
            _emit();
          },
        ),
        if (proposalNodeId != null) ...<Widget>[
          SizedBox(height: spacing.space2),
          HiveTextField(
            key: const Key('config_human_proposal_path'),
            label: l10n.nodeConfigHumanProposalPathLabel,
            hint: l10n.nodeConfigHumanProposalPathHint,
            controller: _proposalPathController,
            errorText: _issueFor(issues, 'proposalPath'),
            onChanged: (_) {
              setState(() {});
              _emit();
            },
          ),
          SizedBox(height: spacing.space2),
          HiveTextArea(
            key: const Key('config_human_proposal_schema'),
            label: l10n.nodeConfigHumanProposalSchemaLabel,
            hintText: l10n.nodeConfigHumanProposalSchemaHint,
            mono: true,
            maxLines: 10,
            controller: _proposalSchemaController,
            errorText: _issueFor(issues, 'proposalSchema'),
            onChanged: (_) {
              setState(() {});
              _emit();
            },
          ),
        ],
      ],
    );
  }
}
